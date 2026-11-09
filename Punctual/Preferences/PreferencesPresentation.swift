//
//  PreferencesPresentation.swift
//  MeetingBar
//

import Foundation

struct CalendarSourcePresentation: Equatable, Identifiable {
    let provider: EventStoreProvider
    let titleKey: String
    let descriptionKey: String
    let dataSourceKey: String
    let accountScopeKey: String
    let authorizationDescriptionKey: String
    let systemImage: String

    var id: EventStoreProvider { provider }

    /// Every calendar source, in display order, regardless of build credentials.
    ///
    /// Google is listed even without a shipped OAuth client, because a user can supply one
    /// at runtime. Whether a source can sign in is `CalendarSourceKind.isAvailableInThisBuild`.
    static var all: [CalendarSourcePresentation] {
        CalendarSourceKind.displayOrder.map { make(for: $0.provider) }
    }

    static func make(for provider: EventStoreProvider) -> CalendarSourcePresentation {
        switch provider {
        case .macOSEventKit:
            CalendarSourcePresentation(
                provider: provider,
                titleKey: "onboarding_apple_calendar_title",
                descriptionKey: "onboarding_apple_calendar_description",
                dataSourceKey: "access_screen_provider_macos_data_source",
                accountScopeKey: "access_screen_provider_macos_number_of_accounts",
                authorizationDescriptionKey: "onboarding_authorization_apple_description",
                systemImage: "calendar"
            )
        case .googleCalendar:
            CalendarSourcePresentation(
                provider: provider,
                titleKey: "onboarding_google_calendar_title",
                descriptionKey: "onboarding_google_calendar_description",
                dataSourceKey: "access_screen_provider_gcalendar_data_source",
                accountScopeKey: "access_screen_provider_gcalendar_number_of_accounts",
                authorizationDescriptionKey: "onboarding_authorization_google_description",
                systemImage: "globe"
            )
        }
    }
}

enum PreferencesStatusTone: Equatable {
    case neutral
    case success
    case warning
    case error
}

enum PreferencesProviderConnectionState: Equatable {
    case initializing
    case connected
    case authRequired
    case permissionRequired
    case stale
    case error
}

struct PreferencesCalendarPresentation: Equatable {
    let activeProvider: EventStoreProvider
    let connectionState: PreferencesProviderConnectionState
    let statusTone: PreferencesStatusTone
    let selectedCalendarCount: Int
    let availableCalendarCount: Int
    let canReconnect: Bool
    let canRequestAccess: Bool
    let canOpenCalendarSettings: Bool
    let providerTitleKey: String
    let providerDataSourceKey: String
    let providerAccountScopeKey: String
    let statusTextKey: String
    let emptyStateTextKey: String
    /// Newest event `lastModifiedDate` from the last successful fetch; `nil` when no event carried one.
    let lastSyncedChange: Date?
    /// Whether to offer the Internet Accounts shortcut; true only for EventKit.
    let canReauthenticateAccount: Bool
    /// Every connected source, in display order. `activeProvider` names only the write-capable one.
    let connectedProviders: [EventStoreProvider]
    /// Sources that are failing while another source still works.
    let degradedSources: [CalendarSourceFailure]

    /// Builds the Calendars pane presentation from app state.
    ///
    /// - Parameters:
    ///   - state: The current app state.
    ///   - authorizationStatus: The live EventKit calendar authorization, injected to keep this pure.
    ///     Defaults to `.authorized`, which never offers "Grant access".
    static func make(
        from state: AppState,
        authorizationStatus: PermissionSnapshot.CalendarAccess = .authorized
    ) -> PreferencesCalendarPresentation {
        let connectionState: PreferencesProviderConnectionState
        var statusTone: PreferencesStatusTone
        var statusTextKey: String

        // Keys are built indirectly; `IndirectLocalizationKeyTests` checks each one resolves.
        if state.providerHealth.authRequired {
            connectionState = .authRequired
            statusTone = .error
            statusTextKey = "preferences_calendars_status_auth_required"
        } else if state.activeProvider == .macOSEventKit,
                  state.providerHealth.lastErrorDescription != nil,
                  state.providerHealth.lastSuccessfulRefresh == nil {
            connectionState = .permissionRequired
            statusTone = .error
            statusTextKey = "preferences_calendars_status_permission_required"
        } else if state.providerHealth.isStale {
            connectionState = .stale
            statusTone = .warning
            statusTextKey = "preferences_calendars_status_stale"
        } else if state.providerHealth.lastErrorDescription != nil {
            connectionState = .error
            statusTone = .error
            statusTextKey = "preferences_calendars_status_error"
        } else if state.providerHealth.lastSuccessfulRefresh != nil {
            connectionState = .connected
            statusTone = .success
            statusTextKey = "preferences_calendars_status_ok"
        } else {
            connectionState = .initializing
            statusTone = .neutral
            statusTextKey = "preferences_calendars_status_initializing"
        }

        let availableCalendarCount = state.calendars.count

        // A successful refresh with zero calendars is reported as a warning, not "Up to date".
        let connectedWithoutCalendars = connectionState == .connected
            && availableCalendarCount == 0
        if connectedWithoutCalendars {
            statusTone = .warning
            statusTextKey = "preferences_calendars_status_no_calendars"
        }

        let calendarSource = CalendarSourcePresentation.make(for: state.activeProvider)

        let emptyStateTextKey = switch connectionState {
        case .authRequired:
            "onboarding_calendar_selection_reconnect"
        case .permissionRequired:
            "onboarding_calendar_selection_permission"
        case .initializing, .connected, .stale, .error:
            connectedWithoutCalendars
                ? "preferences_calendars_empty_no_accounts"
                : "onboarding_calendar_selection_empty"
        }

        let availableIDs = Set(state.calendars.map(\.id))
        let selectedCalendarCount = state.selectedCalendarIDs.filter {
            availableIDs.contains($0)
        }.count

        // TCC can report `.notDetermined` while EventKit is serving calendars (e.g. after
        // re-signing a build), so EventKit calendars present means there is nothing to grant.
        let eventKitCalendarCount = state.calendars
            .filter { $0.provider == .macOSEventKit }
            .count
        let eventKitAccessDemonstrablyWorks = eventKitCalendarCount > 0

        let canRequestAccess = state.connectedProviders.contains(.macOSEventKit)
            && authorizationStatus == .notDetermined
            && !eventKitAccessDemonstrablyWorks

        return PreferencesCalendarPresentation(
            activeProvider: state.activeProvider,
            connectionState: connectionState,
            statusTone: statusTone,
            selectedCalendarCount: selectedCalendarCount,
            availableCalendarCount: availableCalendarCount,
            canReconnect: state.activeProvider == .googleCalendar
                && connectionState == .authRequired,
            canRequestAccess: canRequestAccess,
            canOpenCalendarSettings: state.connectedProviders.contains(.macOSEventKit)
                && !canRequestAccess
                && (connectionState == .permissionRequired || connectedWithoutCalendars),
            providerTitleKey: calendarSource.titleKey,
            providerDataSourceKey: calendarSource.dataSourceKey,
            providerAccountScopeKey: calendarSource.accountScopeKey,
            statusTextKey: statusTextKey,
            emptyStateTextKey: emptyStateTextKey,
            lastSyncedChange: state.providerHealth.lastSyncedChange,
            canReauthenticateAccount: state.activeProvider == .macOSEventKit,
            connectedProviders: state.connectedProviders,
            degradedSources: state.providerHealth.degradedSources
        )
    }
}

enum BrowserPickerOptions {
    static func make(
        configured: [Browser],
        selected: Browser,
        systemDefault: Browser = systemDefaultBrowser
    ) -> [Browser] {
        var options = [systemDefault]
        for browser in configured where !options.contains(browser) {
            options.append(browser)
        }
        if !options.contains(selected) {
            options.append(selected)
        }
        return options
    }
}

struct RegexEditDraft: Equatable, Identifiable {
    let originalValue: String?
    var value: String

    /// Identity for `.sheet(item:)`; an add (`originalValue == nil`) uses the empty string.
    var id: String { originalValue ?? "" }

    static func adding() -> RegexEditDraft {
        RegexEditDraft(originalValue: nil, value: "")
    }

    static func editing(_ regex: String) -> RegexEditDraft {
        RegexEditDraft(originalValue: regex, value: regex)
    }
}

enum RegexListSaveResult: Equatable {
    case saved([String])
    case duplicate
    case originalMissing
}

enum RegexListEditingPolicy {
    static func saving(
        _ draft: RegexEditDraft,
        in regexes: [String]
    ) -> RegexListSaveResult {
        if let originalValue = draft.originalValue {
            guard let index = regexes.firstIndex(of: originalValue) else {
                return .originalMissing
            }
            guard draft.value == originalValue || !regexes.contains(draft.value) else {
                return .duplicate
            }

            var updated = regexes
            updated[index] = draft.value
            return .saved(updated)
        }

        guard !regexes.contains(draft.value) else {
            return .duplicate
        }
        return .saved(regexes + [draft.value])
    }
}

enum MeetingProviderOpeningSelection: Hashable {
    case browser(Browser)
    case mode(MeetingOpeningMode)
}

struct MeetingProviderOpeningPreferences: Equatable {
    let providerBrowsers: [String: Browser]
    let providerOpeningModes: [String: String]
}

enum MeetingProviderOpeningSelectionPolicy {
    static func selected(
        provider: MeetingProvider,
        providerBrowsers: [String: Browser],
        providerOpeningModes: [String: String]
    ) -> MeetingProviderOpeningSelection {
        if let modeID = providerOpeningModes[provider.id],
           let mode = MeetingOpeningMode(rawValue: modeID),
           provider.openingModes.contains(mode) {
            return .mode(mode)
        }
        if let browser = providerBrowsers[provider.id] {
            if let mode = legacyOpeningMode(for: provider, browser: browser) {
                return .mode(mode)
            }
            return .browser(browser)
        }
        return .browser(systemDefaultBrowser)
    }

    static func updating(
        provider: MeetingProvider,
        selection: MeetingProviderOpeningSelection,
        providerBrowsers: [String: Browser],
        providerOpeningModes: [String: String]
    ) -> MeetingProviderOpeningPreferences {
        var browsers = providerBrowsers
        var modes = providerOpeningModes

        switch selection {
        case .browser(let browser):
            modes.removeValue(forKey: provider.id)
            if browser == systemDefaultBrowser {
                browsers.removeValue(forKey: provider.id)
            } else {
                browsers[provider.id] = browser
            }
        case .mode(let mode):
            guard provider.openingModes.contains(mode) else {
                modes.removeValue(forKey: provider.id)
                return MeetingProviderOpeningPreferences(
                    providerBrowsers: browsers,
                    providerOpeningModes: modes
                )
            }
            modes[provider.id] = mode.rawValue
            if let browser = browsers[provider.id],
               legacyOpeningMode(for: provider, browser: browser) != nil {
                browsers.removeValue(forKey: provider.id)
            }
        }

        return MeetingProviderOpeningPreferences(
            providerBrowsers: browsers,
            providerOpeningModes: modes
        )
    }
}
