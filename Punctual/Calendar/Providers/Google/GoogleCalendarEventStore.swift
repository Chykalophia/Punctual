//
//  GoogleCalendarEventStore.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 21.11.2021.
//  Copyright © 2021 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppAuth
import AppAuthCore
import AppKit
import Defaults
import Foundation

/// Google OAuth configuration read from the app's Info.plist, populated at
/// build time from `XCConfig/GoogleSecrets.xcconfig`. A missing or placeholder
/// value leaves `isConfigured == false` rather than trapping.
enum GoogleOAuthConfig {
    /// The build's client id, as a full id or just the number.
    /// Falls back to the legacy `GOOGLE_CLIENT_NUMBER` key so existing xcconfigs keep working.
    static let clientNumber: String = {
        let current = infoString("GOOGLE_CLIENT_ID")
        guard GoogleOAuthClientResolver.isValidClientID(current) else {
            return infoString("GOOGLE_CLIENT_NUMBER")
        }
        return current
    }()
    static let clientSecret = infoString("GOOGLE_CLIENT_SECRET")
    static let keychainName = infoString("GOOGLE_AUTH_KEYCHAIN_NAME")

    /// The client secret as AppAuth must receive it: `nil` when there isn't one.
    ///
    /// Must be nil, not `""`: AppAuth treats an empty NSString as present and switches to
    /// HTTP Basic client auth, which Google rejects with `invalid_client` for secretless clients.
    static var oauthClientSecret: String? { normalizedSecret(clientSecret) }

    /// Maps an empty secret to `nil`.
    static func normalizedSecret(_ secret: String) -> String? {
        secret.isEmpty ? nil : secret
    }

    /// True when the current build carries real OAuth credentials.
    ///
    /// Describes the build only; Google is usable whenever `effectiveClient != nil`,
    /// which a user-supplied client also satisfies.
    static var isConfigured: Bool {
        isConfigured(clientNumber: clientNumber, clientSecret: clientSecret, keychainName: keychainName)
    }

    /// Validates raw configuration values.
    ///
    /// The client number and keychain name must be non-empty and not the build placeholder.
    /// The client secret may be empty (secretless clients) but must not be the placeholder.
    static func isConfigured(clientNumber: String, clientSecret: String, keychainName: String) -> Bool {
        !clientNumber.isEmpty && !clientNumber.hasPrefix("REPLACE_BY_YOUR")
            && !keychainName.isEmpty && !keychainName.hasPrefix("REPLACE_BY_YOUR")
            && !clientSecret.hasPrefix("REPLACE_BY_YOUR")
    }

    private static func infoString(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }
}

let googleClientNumber = GoogleOAuthConfig.clientNumber
let googleAuthKeychainName = GoogleOAuthConfig.keychainName
// No `googleClientSecret` alias on purpose: pass the secret only via
// `GoogleOAuthConfig.oauthClientSecret`, which maps "no secret" to nil.

extension OIDServiceConfiguration: @unchecked @retroactive Sendable {}

extension OIDAuthState {
    /// token is considered fresh if it expires later than 300 seconds from now
    var isTokenFresh: Bool {
        guard let exp = lastTokenResponse?.accessTokenExpirationDate else { return false }
        return exp > Date().addingTimeInterval(300)
    }

    /// The signed-in account address, from the ID token's `email` claim.
    var userEmail: String? {
        GoogleIDToken.email(fromIDToken: lastTokenResponse?.idToken)
    }
}

// MARK: - GCEventStore
@MainActor
final class GCEventStore: NSObject,
                           AuthenticatedEventStore,
                           @preconcurrency OIDExternalUserAgent,
                          @preconcurrency OIDAuthStateChangeDelegate,
                          @preconcurrency OIDAuthStateErrorDelegate {

    // MARK: Static constants
    private static let kIssuer       = "https://accounts.google.com"
    private static let kKeychainName = googleAuthKeychainName

    /// Loopback HTTP listener (127.0.0.1, ephemeral port) that receives the OAuth redirect for one sign-in.
    ///
    /// Loopback, not a custom URL scheme: a scheme must be declared at build time (blocking runtime
    /// client ids) and can be registered by another app to intercept the code.
    /// Requires the `com.apple.security.network.server` entitlement.
    private var redirectHandler: OIDRedirectHTTPHandler?

    /// Serves the branded "connected" page the browser is redirected to after sign-in.
    /// Kept separate from `redirectHandler` so AppAuth owns the whole OAuth-critical path.
    private let completionPage = OAuthCompletionPageServer()

    // MARK: Stored properties
    @MainActor var currentAuthorizationFlow: OIDExternalUserAgentSession?
    private(set) var userEmail: String?

    private var authState: OIDAuthState? {
        didSet {
            authState?.stateChangeDelegate = self
            authState?.errorDelegate       = self
            userEmail = authState?.userEmail
            persistAuthState()
        }
    }

    /// Google's event colour palette, cached for the run as Google's `/colors` docs request.
    private var cachedPalette: GoogleColorPalette?

    private var signInTask: Task<Void, Error>?
    private var refreshTask: Task<String, Error>?

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpMaximumConnectionsPerHost = 6
        cfg.waitsForConnectivity          = true
        return URLSession(configuration: cfg)
    }()
    private var urlSession: URLSession { Self.session }

    static let shared = GCEventStore()
    private override init() {
        super.init()
        self.authState = restoreAuthState()
        // `didSet` does not run for assignments inside `init`, so delegates and
        // the account address are applied explicitly here.
        self.authState?.stateChangeDelegate = self
        self.authState?.errorDelegate       = self
        self.userEmail = self.authState?.userEmail
    }

    // MARK: Public API

    var isAuthorized: Bool { authState?.isAuthorized == true }

    func signIn(forcePrompt: Bool = false) async throws {
        guard let client = GoogleOAuthConfig.effectiveClient,
              let issuerURL = URL(string: Self.kIssuer)
        else {
            throw AuthError.notConfigured
        }

        // Tokens are bound to the client that issued them. Must run before the
        // reusable-session check: another client's tokens still look valid.
        discardAuthStateIfClientChanged(to: client)

        if Self.shouldSkipSignIn(forcePrompt: forcePrompt, state: authState) {
            return
        }

        // A nil `successURL` (page server could not bind) falls back to AppAuth's
        // plain page; it must never fail the sign-in.
        let successURL = await completionPage.start()

        // Listener must start before the request is built: the redirect URI carries its bound port.
        let handler = OIDRedirectHTTPHandler(successURL: successURL)
        redirectHandler = handler
        var listenerError: NSError?
        let redirectURL = handler.startHTTPListener(&listenerError)
        if let listenerError {
            redirectHandler = nil
            throw listenerError
        }

        let config = try await withCheckedThrowingContinuation { cont in
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuerURL) { cfg, err in
                if let cfg { cont.resume(returning: cfg) } else { cont.resume(throwing: err ?? NSError(domain: "GoogleSignIn", code: -1)) }
            }
        }

        let scopes = [
            "email",
            "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
            "https://www.googleapis.com/auth/calendar.events.readonly"
        ]

        // `access_type=offline` is required for Google to issue a refresh token.
        var extra = [
            "access_type": "offline"
        ]
        if forcePrompt {
            extra["prompt"] = "consent"
        }

        let request = OIDAuthorizationRequest(
            configuration: config,
            clientId: client.clientID,
            clientSecret: client.clientSecret,
            scopes: scopes,
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: extra
        )

        defer {
            redirectHandler?.cancelHTTPListener()
            redirectHandler = nil
            // The page server is deliberately left running: the browser reaches it after
            // the code exchange. It is stopped on the next sign-in or sign-out.
        }

        try await withCheckedThrowingContinuation { cont in
            let session = OIDAuthState.authState(byPresenting: request,
                                                 externalUserAgent: self) { [weak self] state, error in
                guard let self else { return }
                if let state {
                    self.authState = state    // didSet handles persistence & delegates
                    self.userEmail = state.userEmail
                    Defaults[.googleTokenClientIdentity] = client.tokenIdentity
                    self.completionPage.setAccountEmail(state.userEmail)
                    let connected = AppMessage.googleAccountConnected(email: self.userEmail ?? "")
                    if connected.shouldPresent(onboardingCompleted: Defaults[.onboardingCompleted]) {
                        AppMessageCenter.shared.post(connected)
                    }
                    cont.resume()
                } else {
                    cont.resume(throwing: Self.authorizationError(error))
                }
            }
            self.currentAuthorizationFlow = session
            handler.currentAuthorizationFlow = session
        }
    }

    /// Drops any stored session that belongs to a different OAuth client.
    private func discardAuthStateIfClientChanged(to client: GoogleOAuthClient) {
        let stored = Defaults[.googleTokenClientIdentity]
        guard !stored.isEmpty, stored != client.tokenIdentity else { return }
        PunctualLogger.calendar.info(
            "Google OAuth client changed; discarding the previous client's session"
        )
        clearAuthState()
    }

    private static func authorizationError(_ error: Error?) -> Error {
        guard let error else {
            return NSError(domain: "GoogleSignIn", code: 1)
        }

        let nsError = error as NSError
        let cancellationCodes = [-3, -4]
        if nsError.domain == OIDGeneralErrorDomain,
           cancellationCodes.contains(nsError.code) {
            return AuthError.cancelled
        }
        return error
    }

    func signOut() async {
        cancelPendingOperations()
        guard let state = authState else { return }

        let access  = state.lastTokenResponse?.accessToken
        let refresh = state.refreshToken
        await withTaskGroup(of: Void.self) { grp in
            if let acc = access { grp.addTask { try? await self.revoke(token: acc) } }
            if let ref = refresh { grp.addTask { try? await self.revoke(token: ref) } }
        }

        clearAuthState()
    }

    func cancelPendingOperations() {
        signInTask?.cancel()
        signInTask = nil
        refreshTask?.cancel()
        refreshTask = nil

        let flow = currentAuthorizationFlow
        currentAuthorizationFlow = nil
        flow?.cancel()

        redirectHandler?.cancelHTTPListener()
        redirectHandler = nil
        completionPage.stop()
    }

    func refreshSources() async {}

    func fetchAllCalendars() async throws -> [MBCalendar] {
        try await ensureSignedIn()

        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList?maxResults=250&showHidden=true")!
        let items = try await fetchJSON(url)

        return items.compactMap { item -> MBCalendar? in
            guard let title = item["summary"] as? String,
                  let calendarID = item["id"] as? String,
                  let backgroundColor = item["backgroundColor"] as? String else { return nil }

            return MBCalendar(title: title,
                              id: calendarID,
                              source: userEmail,
                              email: userEmail,
                              color: hexStringToUIColor(hex: backgroundColor),
                              provider: .googleCalendar)
        }
    }

    private func getCalendarEventsForDateRange(calendar: MBCalendar,
                                               dateFrom: Date,
                                               dateTo: Date) async throws -> [MBEvent] {
        let iso = ISO8601DateFormatter()
        let timeMin = iso.string(from: dateFrom)
        let timeMax = iso.string(from: dateTo)
        let url = try Self.eventsURL(
            calendarID: calendar.id,
            timeMin: timeMin,
            timeMax: timeMax
        )

        let items = try await fetchJSON(url, calendarID: calendar.id)
        let palette = await eventColorPalette()
        return items.compactMap {
            GCParser.event(from: $0, calendar: calendar, palette: palette)
        }
    }

    static func eventsURL(calendarID: String, timeMin: String, timeMax: String) throws -> URL {
        // Calendar IDs can contain `#`, `@` and `+`; `URLComponents.path` percent-encodes
        // them, where string interpolation into a URL makes Google return 404.
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "www.googleapis.com"
        comps.path = "/calendar/v3/calendars/\(calendarID)/events"
        comps.queryItems = [
            .init(name: "singleEvents", value: "true"),
            .init(name: "orderBy", value: "startTime"),
            .init(name: "eventTypes", value: "default"),
            .init(name: "timeMax", value: timeMax),
            .init(name: "timeMin", value: timeMin)
        ]
        guard let url = comps.url else {
            throw URLError(.badURL)
        }

        return url
    }

    func fetchEventsForDateRange(for calendars: [MBCalendar],
                                 from: Date,
                                 to: Date) async throws -> [MBEvent] {
        try await ensureSignedIn()
        var result: [MBEvent] = []
        var forbiddenErrors: [Error] = []
        var successfulCalendars = 0
        for cal in calendars {
            do {
                let ev = try await getCalendarEventsForDateRange(calendar: cal, dateFrom: from, dateTo: to)
                successfulCalendars += 1
                result.append(contentsOf: ev)
            } catch let error as GoogleCalendarError {
                switch error {
                case .forbiddenCalendar:
                    PunctualLogger.calendar.warning(
                        "Skipping inaccessible Google calendar \(cal.id, privacy: .private): \(error.localizedDescription, privacy: .private)"
                    )
                    forbiddenErrors.append(error)
                default:
                    throw error
                }
            } catch {
                throw error
            }
        }
        let deduplicated = Dictionary(result.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        return try GoogleCalendarBatchPolicy.finish(
            events: Array(deduplicated),
            successfulCalendars: successfulCalendars,
            forbiddenErrors: forbiddenErrors
        )
    }

    // MARK: - Private helpers
    private func ensureSignedIn() async throws {
        if Self.hasReusableSession(authState) {
            return
        }

        let forceConsent = authState?.refreshToken == nil
        if let running = signInTask { return try await running.value }

        let task = Task {
            try await signIn(forcePrompt: forceConsent)
        }
        signInTask = task
        defer { signInTask = nil }
        try await task.value
    }

    nonisolated static func hasReusableSession(_ state: OIDAuthState?) -> Bool {
        state?.isAuthorized == true && state?.refreshToken != nil
    }

    nonisolated static func shouldSkipSignIn(
        forcePrompt: Bool,
        state: OIDAuthState?
    ) -> Bool {
        !forcePrompt && hasReusableSession(state)
    }

    private func validAccessToken(forceRefresh: Bool = false) async throws -> String {
        guard let state = authState else { throw AuthError.notSignedIn }

        if !forceRefresh,
           state.isTokenFresh,
           let token = state.lastTokenResponse?.accessToken {
            return token
        }

        if let running = refreshTask { return try await running.value }

        let task = Task<String, Error> {
            defer { refreshTask = nil }
            return try await withCheckedThrowingContinuation { cont in
                if forceRefresh { state.setNeedsTokenRefresh() }

                state.performAction { [weak self] accessToken, _, error in
                    guard let self else { return }
                    if let token = accessToken {
                        cont.resume(returning: token) // stateChangeDelegate persists new tokens
                    } else if let error {
                        let nsError = error as NSError
                        if nsError.domain == OIDOAuthTokenErrorDomain {
                            self.clearAuthState()
                            cont.resume(throwing: AuthError.notSignedIn)
                        } else {
                            cont.resume(throwing: error)
                        }
                    } else {
                        cont.resume(throwing: AuthError.refreshFailed)
                    }
                }
            }
        }

        refreshTask = task
        return try await task.value
    }

    // MARK: Keychain persistence

    private func persistAuthState() {
        guard let state = authState else {
            Keychain.delete(for: Self.kKeychainName)
            return
        }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: state, requiringSecureCoding: true)
            Keychain.save(data: data, for: Self.kKeychainName)
        } catch {
            let errorDescription = String(describing: error)
            PunctualLogger.calendar.error(
                "Could not archive Google auth state: \(errorDescription, privacy: .private)"
            )
        }
    }

    private func restoreAuthState() -> OIDAuthState? {
        guard let data = Keychain.load(for: Self.kKeychainName) else { return nil }
        do {
            guard let state = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data) else { return nil }
            userEmail = state.userEmail
            return state
        } catch {
            let errorDescription = String(describing: error)
            PunctualLogger.calendar.error(
                "Could not restore Google auth state: \(errorDescription, privacy: .private)"
            )
            return nil
        }
    }

    private func clearAuthState() {
        authState  = nil
        userEmail  = nil
        Keychain.delete(for: Self.kKeychainName)
        cachedPalette = nil
        Defaults[.googleTokenClientIdentity] = ""
    }

    // MARK: Networking helper
    /// Fetches a list endpoint and returns its `items` array.
    private func fetchJSON(_ url: URL, calendarID: String? = nil) async throws -> [[String: Any]] {
        let root = try await fetchRootJSON(url, calendarID: calendarID)
        guard let items = root["items"] as? [[String: Any]] else {
            throw GoogleCalendarError.missingItems(url)
        }
        return items
    }

    /// Fetches an endpoint and returns the raw JSON object, for non-list endpoints such as `/colors`.
    ///
    /// Retries once with a forced token refresh when the status policy asks for it.
    private func fetchRootJSON(
        _ url: URL,
        calendarID: String? = nil,
        retrying: Bool = false
    ) async throws -> [String: Any] {
        let token = try await validAccessToken()

        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: req)

        if let http = response as? HTTPURLResponse {
            switch GoogleHTTPStatusPolicy.classify(
                statusCode: http.statusCode,
                url: url,
                calendarID: calendarID,
                retrying: retrying
            ) {
            case .proceed:
                break
            case .retryWithForcedTokenRefresh:
                _ = try await validAccessToken(forceRefresh: true)
                return try await fetchRootJSON(url, calendarID: calendarID, retrying: true)
            case .clearAuthAndThrowAuthRequired:
                clearAuthState()
                throw AuthError.notSignedIn
            case let .throwError(error):
                throw error
            }
        }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// Google's per-event colour palette, fetched once and kept for the run.
    ///
    /// Never throws: on failure it returns `.empty`, so events use their calendar's colour.
    private func eventColorPalette() async -> GoogleColorPalette {
        if let cachedPalette { return cachedPalette }
        guard let url = URL(string: "https://www.googleapis.com/calendar/v3/colors") else {
            return .empty
        }
        do {
            let palette = GoogleColorPalette.parse(try await fetchRootJSON(url))
            cachedPalette = palette
            return palette
        } catch {
            PunctualLogger.calendar.warning(
                "Could not load Google's event colour palette; falling back to calendar colours: \(error.localizedDescription, privacy: .public)"
            )
            return .empty
        }
    }

    private func revoke(token: String) async throws {
        var req = URLRequest(url: URL(string: "https://oauth2.googleapis.com/revoke")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = Data("token=\(token)".utf8)

        let (_, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "GoogleRevoke", code: (resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    // MARK: - OIDAuthState Delegates
    func didChange(_ state: OIDAuthState) {
        persistAuthState()
    }

    func authState(_ state: OIDAuthState, didEncounterAuthorizationError error: Error) {
        let nsErr = error as NSError
        if nsErr.domain == OIDOAuthTokenErrorDomain {
            clearAuthState()
        }
    }

    // MARK: - OIDExternalUserAgent
    func present(_ request: OIDExternalUserAgentRequest, session _: OIDExternalUserAgentSession) -> Bool {
        if let url = request.externalUserAgentRequestURL(), NSWorkspace.shared.open(url) {
            return true
        }
        return false
    }

    func dismiss(animated _: Bool, completion: @escaping () -> Void) { completion() }

    // MARK: - Google JSON ➜ MBEvent converter
    enum GCParser {
        // swiftlint:disable:next cyclomatic_complexity
        static func event(from item: [String: Any],
                          calendar: MBCalendar,
                          palette: GoogleColorPalette = .empty) -> MBEvent? {
            guard let eventID = item["id"] as? String else {
                PunctualLogger.calendar.warning(
                    "Skipping Google Calendar event without a string id"
                )
                return nil
            }

            let formatter = ISO8601DateFormatter()
            let lastModifiedDate = formatter.date(from: item["updated"] as? String ?? "")
            let title = item["summary"] as? String
            var status: MBEventStatus
            switch item["status"] as? String {
            case "confirmed":
                status = .confirmed
            case "tentative":
                status = .tentative
            case "cancelled":
                status = .canceled
            default:
                status = .none
            }

            let notes = item["description"] as? String
            let location = item["location"] as? String

            // Google has no equivalent of `EKEvent.url`; the meeting link comes from
            // `conferenceData` and is ranked ahead of URLs found in notes.
            var conferenceURL: URL?
            if let conferenceData = item["conferenceData"] as? [String: Any],
               let entryPoints = conferenceData["entryPoints"] as? [[String: Any]],
               let videoEntryPoint = entryPoints.first(where: { $0["entryPointType"] as? String == "video" }) {
                conferenceURL = (videoEntryPoint["uri"] as? String).flatMap(URL.init(string:))
            }

            let organizerRaw = item["organizer"] as? [String: Any]
            let organizer = MBEventOrganizer(email: organizerRaw?["email"] as? String, name: organizerRaw?["name"] as? String)

            var attendees: [MBEventAttendee] = []
            let rawAttendees = item["attendees"] as? [[String: Any]] ?? []
            for jsonAttendee in rawAttendees {
                let email = jsonAttendee["email"] as? String
                let name = jsonAttendee["displayName"] as? String
                let optional = jsonAttendee["optional"] as? Bool ?? false
                let isCurrentUser = jsonAttendee["self"] as? Bool ?? false

                var attendeeStatus: MBEventAttendeeStatus
                switch jsonAttendee["responseStatus"] as? String {
                case "accepted":
                    attendeeStatus = .accepted
                case "declined":
                    attendeeStatus = .declined
                case "tentative":
                    attendeeStatus = .tentative
                case "needsAction":
                    attendeeStatus = .pending
                default:
                    attendeeStatus = .unknown
                }
                let attendee = MBEventAttendee(email: email, name: name, status: attendeeStatus, optional: optional, isCurrentUser: isCurrentUser)
                attendees.append(attendee)
            }

            var startDate: Date
            var endDate: Date
            var isAllDay: Bool

            guard let itemStart = item["start"] as? [String: String],
                  let itemEnd = item["end"] as? [String: String] else {
                PunctualLogger.calendar.warning(
                    "Skipping Google event \(eventID, privacy: .private) without valid start/end dictionaries"
                )
                return nil
            }

            if let startDateTime = itemStart["dateTime"], let endDateTime = itemEnd["dateTime"] {
                let formatter = ISO8601DateFormatter()
                guard let parsedStartDate = formatter.date(from: startDateTime),
                      let parsedEndDate = formatter.date(from: endDateTime) else {
                    PunctualLogger.calendar.warning(
                        "Skipping Google event \(eventID, privacy: .private) with invalid dateTime values"
                    )
                    return nil
                }
                startDate = parsedStartDate
                endDate = parsedEndDate
                isAllDay = false
            } else {
                let formatter = DateFormatter()
                // Fixed POSIX locale and Gregorian calendar so non-Gregorian system calendars
                // parse correctly. All-day dates are floating: keep local midnight, do not force UTC.
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.calendar = Calendar(identifier: .gregorian)
                formatter.dateFormat = "yyyy-MM-dd"
                guard let startDateString = itemStart["date"],
                      let endDateString = itemEnd["date"],
                      let parsedStartDate = formatter.date(from: startDateString),
                      let parsedEndDate = formatter.date(from: endDateString) else {
                    PunctualLogger.calendar.warning(
                        "Skipping Google event \(eventID, privacy: .private) with invalid all-day date values"
                    )
                    return nil
                }
                startDate = parsedStartDate
                endDate = parsedEndDate
                isAllDay = true
            }

            let recurrent = (item["recurringEventId"] != nil) ? true : false

            // Google events need their web link for "Open in Calendar"; `ical://ekevent/` does not resolve them.
            let calendarOpenURL = (item["htmlLink"] as? String).flatMap(URL.init(string:))

            return MBEvent(
                id: eventID,
                lastModifiedDate: lastModifiedDate,
                title: title,
                status: status,
                notes: notes,
                location: location,
                url: nil,
                conferenceURL: conferenceURL,
                calendarOpenURL: calendarOpenURL,
                organizer: organizer,
                attendees: attendees,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                recurrent: recurrent,
                calendar: calendar,
                customRegexes: Defaults[.customRegexes],
                // nil for an absent or unknown `colorId`, so the calendar colour applies.
                color: palette
                    .background(forEventColorID: item["colorId"] as? String)
                    .map { hexStringToUIColor(hex: $0) }
            )
        }
    }
}
