//
//  MeetingLinkDetector.swift
//  MeetingBar
//
//  Extracts a meeting URL from an event: the `MeetingLink` value type, the regex
//  catalogue built from `MeetingProvider.all`, Outlook SafeLink and HTML cleanup,
//  candidate ranking, and the detector.
//

import AppKit
import Foundation

// MARK: - Public value types

/// Meeting service identifiers, used as the key for detection regexes, icons, browser
/// preferences and bookmarks. Raw values are persisted. Metadata lives on `MeetingProvider`.
enum MeetingServices: String, Codable, CaseIterable, Sendable {
    case phone = "Phone"
    case meet = "Google Meet"
    case protonMeet = "Proton Meet"
    case hangouts = "Google Hangouts"
    case zoom = "Zoom"
    case zoom_native = "Zoom native"
    case teams = "Microsoft Teams"
    case webex = "Cisco Webex"
    case jitsi = "Jitsi"
    case chime = "Amazon Chime"
    case ringcentral = "Ring Central"
    case gotomeeting = "GoToMeeting"
    case gotowebinar = "GoToWebinar"
    case bluejeans = "BlueJeans"
    case eight_x_eight = "8x8"
    case demio = "Demio"
    case join_me = "Join.me"
    case zoomgov = "ZoomGov"
    case whereby = "Whereby"
    case uberconference = "Uber Conference"
    case blizz = "Blizz"
    case teamviewer_meeting = "Teamviewer Meeting"
    case vsee = "VSee"
    case starleaf = "StarLeaf"
    case duo = "Google Duo"
    case voov = "Tencent VooV"
    case facebook_workspace = "Facebook Workspace"
    case lifesize = "Lifesize"
    case skype = "Skype"
    case skype4biz = "Skype For Business"
    case skype4biz_selfhosted = "Skype For Business (SH)"
    case facetime = "Facetime"
    case pop = "Pop"
    case chorus = "Chorus"
    case gong = "Gong"
    case livestorm = "Livestorm"
    case facetimeaudio = "Facetime Audio"
    case youtube = "YouTube"
    case vonageMeetings = "Vonage Meetings"
    case meetStream = "Google Meet Stream"
    case around = "Around"
    case jam = "Jam"
    case discord = "Discord"
    case blackboard_collab = "Blackboard Collaborate"
    case url = "Any Link"
    case coscreen = "CoScreen"
    case vowel = "Vowel"
    case zhumu = "Zhumu"
    case lark = "Lark"
    case feishu = "Feishu"
    case vimeo = "Vimeo"
    case ovice = "oVice"
    case luma = "Luma"
    case preply = "Preply"
    case userzoom = "UserZoom"
    case venue = "Venue"
    case teemyco = "Teemyco"
    case demodesk = "Demodesk"
    case zoho_cliq = "Zoho Cliq"
    case slack = "Slack"
    case gather = "Gather"
    case reclaim = "Reclaim.ai"
    case tuple = "Tuple"
    case pumble = "Pumble"
    case suitConference = "Suit Conference"
    case doxyMe = "Doxy.me"
    case calcom = "Cal Video"
    case zmPage = "zm.page"
    case livekit = "LiveKit Meet"
    case meetecho = "Meetecho"
    case streamyard = "StreamYard"
    case riverside = "Riverside"
    case other = "Other"
}

public struct MeetingLink: Hashable, Equatable, Sendable {
    let service: MeetingServices?
    var url: URL
}

/// Where a meeting link candidate was extracted from. Higher-priority sources
/// are preferred when more than one candidate is found for an event.
enum MeetingLinkSource: Hashable, Sendable {
    /// Structured conference data tagged by the provider, e.g. Google Calendar's
    /// `conferenceData.entryPoints[type=video]`.
    case providerConferenceData

    /// The event's explicit URL field.
    case eventURL

    /// The event's location field.
    case location

    /// Free-text notes / description.
    case notes

    /// Notes after HTML stripping. Ranked below raw notes because stripping can alter links.
    case strippedHTMLNotes

    /// A user-provided regex match. Lowest priority, so it never overrides provider data.
    case customRegex

    /// Numeric priority; larger wins.
    var priority: Int {
        switch self {
        case .providerConferenceData: return 60
        case .eventURL: return 50
        case .location: return 40
        case .notes: return 30
        case .strippedHTMLNotes: return 20
        case .customRegex: return 10
        }
    }
}

/// A single meeting-link candidate extracted from one source field of an event.
struct MeetingLinkCandidate: Hashable, Sendable {
    let url: URL
    let service: MeetingServices?
    let source: MeetingLinkSource
}

enum MeetingLinkCandidatePolicy {
    /// The best candidate: highest source priority, then the longest URL, so a link with a
    /// password or token suffix beats a truncated copy.
    static func best(from candidates: [MeetingLinkCandidate]) -> MeetingLinkCandidate? {
        candidates.max { lhs, rhs in
            if lhs.source.priority != rhs.source.priority {
                return lhs.source.priority < rhs.source.priority
            }
            return lhs.url.absoluteString.count < rhs.url.absoluteString.count
        }
    }

    /// Candidates ranked best to worst, deduplicated by URL string.
    static func ranked(from candidates: [MeetingLinkCandidate]) -> [MeetingLinkCandidate] {
        let unique = Dictionary(grouping: candidates, by: { $0.url.absoluteString })
            .compactMapValues { best(from: $0) }
            .values
        return Array(unique).sorted { lhs, rhs in
            if lhs.source.priority != rhs.source.priority {
                return lhs.source.priority > rhs.source.priority
            }
            return lhs.url.absoluteString.count > rhs.url.absoluteString.count
        }
    }
}

// MARK: - Regex catalogue and text helpers

private let meetingLinkRegexes: [MeetingServices: NSRegularExpression] =
    MeetingProvider.regexPatterns.compactMapValues { pattern in
        do {
            return try NSRegularExpression(pattern: pattern)
        } catch {
            assertionFailure("Invalid built-in meeting link regex: \(pattern)")
            return nil
        }
    }

private let outlookSafeLinkRegex = try? NSRegularExpression(
    pattern: #"https://[\S]+\.safelinks\.protection\.outlook\.com/[\S]+url=([\S]*)"#)

func regex(for service: MeetingServices) -> NSRegularExpression? {
    meetingLinkRegexes[service]
}

func detectMeetingLink(_ rawText: String, customRegexes: [String] = []) -> MeetingLink? {
    let text = cleanupOutlookSafeLinks(rawText: rawText)

    for pattern in customRegexes {
        if let regex = try? NSRegularExpression(pattern: pattern),
            let link = getMatch(text: text, regex: regex),
            let url = URL(string: link) {
            return MeetingLink(service: MeetingServices.other, url: url)
        }
    }

    if text.contains("://") {
        for (svc, regex) in meetingLinkRegexes {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                let range = Range(match.range, in: text),
                let url = URL(string: String(text[range])) {
                return MeetingLink(service: svc, url: url)
            }
        }
    }
    return nil
}

/// Replaces Outlook SafeLink wrappers in `rawText` with their decoded targets,
/// including nested ones.
func cleanupOutlookSafeLinks(rawText: String) -> String {
    guard let outlookSafeLinkRegex else { return rawText }

    var text = rawText
    autoreleasepool {
        // Bounded: stops on an undecodable `url=` value, on no progress, or at the pass cap,
        // so a malformed SafeLink cannot wedge calendar sync.
        let maxPasses = 32
        for _ in 0 ..< maxPasses {
            let matches = outlookSafeLinkRegex.matches(
                in: text, range: NSRange(text.startIndex..., in: text))
            guard let match = matches.first,
                  let fullRange = Range(match.range, in: text)
            else { break }

            let safeLink = String(text[fullRange])
            let encodedTarget = (text as NSString).substring(with: match.range(at: 1))
            guard let decodedTarget = encodedTarget.removingPercentEncoding else { break }

            let updated = text.replacingOccurrences(of: safeLink, with: decodedTarget)
            guard updated != text else { break }
            text = updated
        }
    }
    return text
}

func getMatch(text: String, regex: NSRegularExpression) -> String? {
    var match: String?

    autoreleasepool {
        let resultsIterator = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let resultsMap = resultsIterator.compactMap { result -> String? in
            guard let range = Range(result.range, in: text) else { return nil }
            return String(text[range])
        }

        if !resultsMap.isEmpty {
            match = resultsMap[0]
        }
    }

    return match
}

func htmlTagsStrippedForMeetingLinks(_ text: String) -> String {
    if !text.containsHTMLTags {
        return text
    }

    return autoreleasepool {
        guard let dataUTF16 = text.data(using: .utf16) else {
            return text
        }

        let attributedString = NSAttributedString(
            html: dataUTF16,
            options: [.documentType: NSAttributedString.DocumentType.html],
            documentAttributes: nil
        )
        return attributedString?.string ?? text
    }
}

extension String {
    fileprivate var containsHTMLTags: Bool {
        range(of: #"</?[A-z][ \t\S]*>"#, options: .regularExpression) != nil
    }
}

// MARK: - Detector

/// Picks the best meeting link from an event's fields. Each field yields candidates
/// tagged with a `MeetingLinkSource` and ranked by `MeetingLinkCandidatePolicy`.
/// Google Meet URLs get an `authuser` query parameter when an account email is known.
enum MeetingLinkDetector {
    static func detect(
        conferenceURL: URL? = nil,
        location: String?,
        eventURL: URL?,
        notes: String?,
        calendarEmail: String?,
        currentUserEmail: String?,
        customRegexes: [String] = []
    ) -> MeetingLink? {
        guard let best = bestCandidate(
            conferenceURL: conferenceURL,
            location: location,
            eventURL: eventURL,
            notes: notes,
            calendarEmail: calendarEmail,
            currentUserEmail: currentUserEmail,
            customRegexes: customRegexes
        ) else { return nil }
        return MeetingLink(service: best.service, url: best.url)
    }

    static func bestCandidate(
        conferenceURL: URL? = nil,
        location: String?,
        eventURL: URL?,
        notes: String?,
        calendarEmail: String?,
        currentUserEmail: String?,
        customRegexes: [String] = []
    ) -> MeetingLinkCandidate? {
        allCandidates(
            conferenceURL: conferenceURL,
            location: location,
            eventURL: eventURL,
            notes: notes,
            calendarEmail: calendarEmail,
            currentUserEmail: currentUserEmail,
            customRegexes: customRegexes
        ).first
    }

    static func allCandidates(
        conferenceURL: URL? = nil,
        location: String?,
        eventURL: URL?,
        notes: String?,
        calendarEmail: String?,
        currentUserEmail: String?,
        customRegexes: [String] = []
    ) -> [MeetingLinkCandidate] {
        let candidates = collectCandidates(
            conferenceURL: conferenceURL,
            location: location,
            eventURL: eventURL,
            notes: notes,
            customRegexes: customRegexes
        )
        return MeetingLinkCandidatePolicy.ranked(from: candidates)
            .map {
                applyMeetAuthuserIfNeeded(
                    candidate: $0,
                    calendarEmail: calendarEmail,
                    currentUserEmail: currentUserEmail
                )
            }
    }

    private static func collectCandidates(
        conferenceURL: URL?,
        location: String?,
        eventURL: URL?,
        notes: String?,
        customRegexes: [String]
    ) -> [MeetingLinkCandidate] {
        var candidates: [MeetingLinkCandidate] = []

        if let conferenceURL {
            // An unmatched conference URL is `.other` but keeps conference-data priority.
            let service = detectMeetingLink(conferenceURL.absoluteString)?.service ?? .other
            candidates.append(MeetingLinkCandidate(
                url: conferenceURL,
                service: service,
                source: .providerConferenceData
            ))
        }

        if let eventURL {
            candidates.append(contentsOf: builtInCandidates(
                in: eventURL.absoluteString,
                source: .eventURL
            ))
        }

        if let location {
            candidates.append(contentsOf: builtInCandidates(
                in: location,
                source: .location
            ))
        }

        if let notes {
            candidates.append(contentsOf: builtInCandidates(
                in: notes,
                source: .notes
            ))

            // Only when stripping changed the text; otherwise it duplicates the notes candidate.
            let stripped = htmlTagsStrippedForMeetingLinks(notes)
            if stripped != notes {
                candidates.append(contentsOf: builtInCandidates(
                    in: stripped,
                    source: .strippedHTMLNotes
                ))
            }
        }

        // Custom regexes run over the combined text fields.
        if !customRegexes.isEmpty {
            let combined = [location, eventURL?.absoluteString, notes]
                .compactMap { $0 }
                .joined(separator: "\n")
            if let detected = detectCustomRegexLink(text: combined, patterns: customRegexes) {
                candidates.append(MeetingLinkCandidate(
                    url: detected.url,
                    service: detected.service,
                    source: .customRegex
                ))
            }
        }

        return candidates
    }

    private static func builtInCandidates(
        in rawText: String,
        source: MeetingLinkSource
    ) -> [MeetingLinkCandidate] {
        let text = cleanupOutlookSafeLinks(rawText: rawText)
        guard text.contains("://") else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        return MeetingServices.allCases.flatMap { service -> [MeetingLinkCandidate] in
            guard let regex = regex(for: service) else { return [] }
            return regex.matches(in: text, range: range).compactMap { match in
                guard let matchRange = Range(match.range, in: text),
                      let url = URL(string: String(text[matchRange]))
                else { return nil }
                return MeetingLinkCandidate(
                    url: url,
                    service: service,
                    source: source
                )
            }
        }
    }

    private static func detectCustomRegexLink(text: String, patterns: [String]) -> MeetingLink? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text),
               let url = URL(string: String(text[matchRange])) {
                return MeetingLink(service: .other, url: url)
            }
        }
        return nil
    }

    private static func applyMeetAuthuserIfNeeded(
        candidate: MeetingLinkCandidate,
        calendarEmail: String?,
        currentUserEmail: String?
    ) -> MeetingLinkCandidate {
        guard candidate.service == .meet,
              let authAccount = currentUserEmail ?? calendarEmail,
              let urlWithAuth = url(candidate.url, appendingAuthuser: authAccount)
        else { return candidate }
        return MeetingLinkCandidate(
            url: urlWithAuth,
            service: candidate.service,
            source: candidate.source
        )
    }

    private static func url(_ url: URL, appendingAuthuser authAccount: String) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "authuser" }
        queryItems.append(URLQueryItem(name: "authuser", value: authAccount))
        components.queryItems = queryItems
        return components.url
    }
}

// MARK: - Opening policy

/// Input to `MeetingOpeningPolicy`, which decides what joining an event does.
/// `MeetingOpener` performs the side effects.
struct MeetingOpeningEvent: Equatable {
    let title: String
    let meetingLink: MeetingLink?
    let eventURL: URL?
}

enum MeetingOpeningAction: Equatable {
    case openMeetingLink(MeetingLink, runJoinScript: Bool)
    case openEventURL(URL)
    case notifyMissingLink(title: String)
}

enum MeetingOpeningPolicy {
    static func action(
        for event: MeetingOpeningEvent,
        runJoinEventScript: Bool
    ) -> MeetingOpeningAction {
        if let meetingLink = event.meetingLink {
            return .openMeetingLink(meetingLink, runJoinScript: runJoinEventScript)
        }

        if let eventURL = event.eventURL {
            return .openEventURL(eventURL)
        }

        return .notifyMissingLink(title: event.title)
    }
}
