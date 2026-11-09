//
//  AppSettings.swift
//  MeetingBar
//
//  Value-type snapshot of all user-configurable settings.
//  `AppSettings.current` is the single boundary that reads `Defaults`.
//  Feature logic should consume an `AppSettings` (or sub-struct) by value.
//

import Defaults
import Foundation

// MARK: - Sub-structs

struct CalendarSettings: Equatable {
    var selectedCalendarIDs: [String]
    var eventStoreProvider: EventStoreProvider
}

struct EventDisplaySettings: Equatable {
    var showEventsForPeriod: ShowEventsForPeriod
    var allDayEvents: AlldayEventsAppereance
    var nonAllDayEvents: NonAlldayEventsAppereance
    var declinedEventsAppearance: DeclinedEventsAppereance
    var pastEventsAppearance: PastEventsAppereance
    var personalEventsAppearance: PastEventsAppereance
    var showPendingEvents: PendingEventsAppereance
    var showTentativeEvents: TentativeEventsAppereance
    var filterEventRegexes: [String]
    var dismissedEvents: [ProcessedEvent]
    var ongoingEventVisibility: OngoingEventVisibility
    var showEventMaxTimeUntilEventEnabled: Bool
    var showEventMaxTimeUntilEventThreshold: Int
}

struct StatusBarSettings: Equatable {
    var eventTitleFormat: EventTitleFormat
    var eventTimeFormat: EventTimeFormat
    var eventTitleIconFormat: EventTitleIconFormat
    var statusbarEventTitleLength: Int
    var hideMeetingTitle: Bool
    var showEventEndTime: Bool
}

struct MenuSettings: Equatable {
    var showTimelineInMenu: Bool
    var shortenEventTitle: Bool
    var menuEventTitleLength: Int
    var showEventDetails: Bool
    var showMeetingServiceIcon: Bool
    var showEventCalendarColor: Bool
    /// When true, reference links found in an event's invite are shown as rows in the event detail submenu.
    var showMeetingPrepLinks: Bool
    /// When true, the menu's day list hides meetings that ended more than the grace period ago.
    var hideFinishedEventsInMenu: Bool
    /// Minutes before a meeting starts at which its action control becomes a full-strength call to action.
    var eventActionHighlightMinutes: Int
    /// When true, Apple Reminders due today are shown in the dropdown's Today section.
    var showRemindersInMenu: Bool
    /// When true, overdue reminders are included alongside those due today.
    var remindersIncludeOverdue: Bool
    /// When true, the next/current meeting control card is shown.
    var showMeetingControlInMenu: Bool
    /// When true, the today/tomorrow agenda (dates + reminders) is shown.
    var showAgendaInMenu: Bool
    /// When true, the join / create / quick-actions section is shown.
    var showJoinSectionInMenu: Bool
    /// When true, the saved bookmarks section is shown.
    var showBookmarksInMenu: Bool
    /// When true, the compact month grid is shown.
    var showCalendarInMenu: Bool
    /// When true, the up-next progress card is shown.
    var showUpNextInMenu: Bool
}

struct NotificationSettings: Equatable {
    var joinEventNotification: Bool
    var joinEventNotificationTime: TimeBeforeEvent
    var endOfEventNotification: Bool
    var endOfEventNotificationTime: TimeBeforeEventEnd
    var fullscreenNotification: Bool
    var fullscreenNotificationTime: TimeBeforeEvent
    var fullscreenNotificationsForEventsWithoutMeetingLink: Bool
}

struct MeetingSettings: Equatable {
    var createMeetingService: CreateMeetingServices
    var createMeetingServiceUrl: String
    var bookmarks: [Bookmark]
    var browsers: [Browser]
    var defaultBrowser: Browser
    var browserForCreateMeeting: Browser
    /// Per-provider browser preferences, keyed by provider ID.
    var providerBrowsers: [String: Browser]
    var providerOpeningModes: [String: String]
}

struct AdvancedSettings: Equatable {
    var automaticEventJoin: Bool
    var automaticEventJoinTime: TimeBeforeEvent
    var runJoinEventScript: Bool
    var joinEventScriptLocation: URL?
    var joinEventScript: String
    var runEventStartScript: Bool
    var eventStartScriptLocation: URL?
    var eventStartScriptTime: TimeBeforeEvent
    var eventStartScript: String
    var customRegexes: [String]
}

// MARK: - Root

struct AppSettings: Equatable {
    var calendar: CalendarSettings
    var events: EventDisplaySettings
    var statusBar: StatusBarSettings
    var menu: MenuSettings
    var notifications: NotificationSettings
    var meetings: MeetingSettings
    var advanced: AdvancedSettings
}

enum StatusBarTitleFormatMigration {
    @MainActor
    static func migrateDefaultsIfNeeded() {
        guard Defaults[.hideMeetingTitle] else { return }

        if Defaults[.eventTitleFormat] == .show {
            Defaults[.eventTitleFormat] = .generic
        }
        Defaults[.hideMeetingTitle] = false
    }
}

/// One-time migration that pins existing installs which never chose a time format to 24-hour,
/// since the key's default is 12-hour.
enum TimeFormatDefaultMigration {
    /// True for an install past onboarding with no stored time format.
    static func shouldPinToMilitary(onboardingCompleted: Bool, hasStoredTimeFormat: Bool) -> Bool {
        onboardingCompleted && !hasStoredTimeFormat
    }

    @MainActor
    static func migrateDefaultsIfNeeded() {
        guard !Defaults[.timeFormatDefaultMigrated] else { return }
        Defaults[.timeFormatDefaultMigrated] = true

        // A nil raw value means the user never changed the picker.
        let hasStored = UserDefaults.standard.object(forKey: "timeFormat") != nil
        if shouldPinToMilitary(
            onboardingCompleted: Defaults[.onboardingCompleted],
            hasStoredTimeFormat: hasStored
        ) {
            Defaults[.timeFormat] = .military
        }
    }
}

/// Defaults plumbing for `DropdownModuleMergePolicy`, which holds the decisions.
enum DropdownModuleMergeMigration {
    @MainActor
    static func migrateDefaultsIfNeeded() {
        guard !Defaults[.dropdownModuleMergeMigrated] else { return }
        Defaults[.dropdownModuleMergeMigrated] = true

        Defaults[.meetingCardShowsProgress] = DropdownModuleMergePolicy.showsProgress(
            hadUpNextModule: Defaults[.showUpNextInMenu]
        )
        Defaults[.timelineStyle] = DropdownModuleMergePolicy.timelineStyle(
            wasVisible: Defaults[.showTimelineInMenu],
            stored: TimelineSpan(rawValue: Defaults[.timelineStyle]) ?? .relative
        ).rawValue
    }
}

/// One-time migration that resets an inherited upstream changelog version (major >= 1) to "0.0.0",
/// so the strictly-greater "What's new" compare can fire again.
enum ChangelogResetMigration {
    /// True when the stored version's major component is >= 1; false for nil, sub-1.0 or unparseable values.
    ///
    /// Runs once per install (`changelogResetMigrated`), so the app's own 1.x versions are never reset.
    static func shouldReset(storedLastRevised: String?) -> Bool {
        guard let stored = storedLastRevised,
              let majorText = stored.split(separator: ".").first,
              let major = Int(majorText)
        else { return false }
        return major >= 1
    }

    @MainActor
    static func migrateDefaultsIfNeeded() {
        guard !Defaults[.changelogResetMigrated] else { return }
        Defaults[.changelogResetMigrated] = true

        let stored = UserDefaults.standard.string(forKey: "lastRevisedVersionInChangelog")
        if shouldReset(storedLastRevised: stored) {
            Defaults[.lastRevisedVersionInChangelog] = "0.0.0"
        }
    }
}

/// One-time migration of the retired `eventTimeFormat` setting into the menu bar composer.
///
/// Seeds the block list from the legacy settings and turns on Two lines for `.show_under_title`.
/// Installs that already have a composed menu bar are left unchanged.
/// Defaults plumbing only; the decision is `MenuBarTimeFormatMigration`.
enum MenuBarTimeFormatDefaultsMigration {
    @MainActor
    static func migrateDefaultsIfNeeded() {
        guard !Defaults[.menuBarTimeFormatMigrated] else { return }
        Defaults[.menuBarTimeFormatMigrated] = true

        let plan = MenuBarTimeFormatMigration.plan(
            storedTokens: Defaults[.menuBarTokens],
            legacyTokens: MenuBarComposition.derivedFromLegacy.tokens.map(\.rawValue),
            timeUnderTitle: Defaults[.eventTimeFormat] == .show_under_title
        )
        if let tokens = plan.tokens {
            Defaults[.menuBarTokens] = tokens
        }
        if let twoLines = plan.twoLines {
            Defaults[.menuBarTwoLineLayout] = twoLines
        }
        PunctualLogger.preferences.info(
            "Migrated eventTimeFormat: seeded \(plan.tokens?.count ?? 0, privacy: .public) blocks"
        )
    }
}

// MARK: - Defaults factory

extension AppSettings {
    /// The single boundary that reads `Defaults` for app-level feature logic.
    /// Other code should receive `AppSettings` (or sub-structs) by value.
    @MainActor
    static var current: AppSettings {
        let eventTitleFormat = Defaults[.eventTitleFormat]

        return AppSettings(
            calendar: CalendarSettings(
                selectedCalendarIDs: Defaults[.selectedCalendarIDs],
                eventStoreProvider: Defaults[.eventStoreProvider]
            ),
            events: EventDisplaySettings(
                showEventsForPeriod: Defaults[.showEventsForPeriod],
                allDayEvents: Defaults[.allDayEvents],
                nonAllDayEvents: Defaults[.nonAllDayEvents],
                declinedEventsAppearance: Defaults[.declinedEventsAppereance],
                pastEventsAppearance: Defaults[.pastEventsAppereance],
                personalEventsAppearance: Defaults[.personalEventsAppereance],
                showPendingEvents: Defaults[.showPendingEvents],
                showTentativeEvents: Defaults[.showTentativeEvents],
                filterEventRegexes: Defaults[.filterEventRegexes],
                dismissedEvents: Defaults[.dismissedEvents],
                ongoingEventVisibility: Defaults[.ongoingEventVisibility],
                showEventMaxTimeUntilEventEnabled: Defaults[.showEventMaxTimeUntilEventEnabled],
                showEventMaxTimeUntilEventThreshold: Defaults[.showEventMaxTimeUntilEventThreshold]
            ),
            statusBar: StatusBarSettings(
                eventTitleFormat: eventTitleFormat,
                eventTimeFormat: Defaults[.eventTimeFormat],
                eventTitleIconFormat: Defaults[.eventTitleIconFormat],
                statusbarEventTitleLength: Defaults[.statusbarEventTitleLength],
                hideMeetingTitle: eventTitleFormat == .generic,
                showEventEndTime: Defaults[.showEventEndTime]
            ),
            menu: MenuSettings(
                showTimelineInMenu: Defaults[.showTimelineInMenu],
                shortenEventTitle: Defaults[.shortenEventTitle],
                menuEventTitleLength: Defaults[.menuEventTitleLength],
                showEventDetails: Defaults[.showEventDetails],
                showMeetingServiceIcon: Defaults[.showMeetingServiceIcon],
                showEventCalendarColor: Defaults[.showEventCalendarColor],
                showMeetingPrepLinks: Defaults[.showMeetingPrepLinks],
                hideFinishedEventsInMenu: Defaults[.hideFinishedEventsInMenu],
                eventActionHighlightMinutes: Defaults[.eventActionHighlightMinutes],
                showRemindersInMenu: Defaults[.showRemindersInMenu],
                remindersIncludeOverdue: Defaults[.remindersIncludeOverdue],
                showMeetingControlInMenu: Defaults[.showMeetingControlInMenu],
                showAgendaInMenu: Defaults[.showAgendaInMenu],
                showJoinSectionInMenu: Defaults[.showJoinSectionInMenu],
                showBookmarksInMenu: Defaults[.showBookmarksInMenu],
                showCalendarInMenu: Defaults[.showCalendarInMenu],
                showUpNextInMenu: Defaults[.showUpNextInMenu]
            ),
            notifications: NotificationSettings(
                joinEventNotification: Defaults[.joinEventNotification],
                joinEventNotificationTime: Defaults[.joinEventNotificationTime],
                endOfEventNotification: Defaults[.endOfEventNotification],
                endOfEventNotificationTime: Defaults[.endOfEventNotificationTime],
                fullscreenNotification: Defaults[.fullscreenNotification],
                fullscreenNotificationTime: Defaults[.fullscreenNotificationTime],
                fullscreenNotificationsForEventsWithoutMeetingLink:
                    Defaults[.fullscreenNotificationsForEventsWithoutMeetingLink]
            ),
            meetings: MeetingSettings(
                createMeetingService: Defaults[.createMeetingService],
                createMeetingServiceUrl: Defaults[.createMeetingServiceUrl],
                bookmarks: Defaults[.bookmarks],
                browsers: Defaults[.browsers],
                defaultBrowser: Defaults[.defaultBrowser],
                browserForCreateMeeting: Defaults[.browserForCreateMeeting],
                providerBrowsers: Defaults[.providerBrowsers],
                providerOpeningModes: Defaults[.providerOpeningModes]
            ),
            advanced: AdvancedSettings(
                automaticEventJoin: Defaults[.automaticEventJoin],
                automaticEventJoinTime: Defaults[.automaticEventJoinTime],
                runJoinEventScript: Defaults[.runJoinEventScript],
                joinEventScriptLocation: Defaults[.joinEventScriptLocation],
                joinEventScript: Defaults[.joinEventScript],
                runEventStartScript: Defaults[.runEventStartScript],
                eventStartScriptLocation: Defaults[.eventStartScriptLocation],
                eventStartScriptTime: Defaults[.eventStartScriptTime],
                eventStartScript: Defaults[.eventStartScript],
                customRegexes: Defaults[.customRegexes]
            )
        )
    }

    /// Clean-install `AppSettings` mirroring the defaults in `Extensions/DefaultsKeys.swift`,
    /// built without reading `Defaults`.
    static var empty: AppSettings {
        AppSettings(
            calendar: CalendarSettings(
                selectedCalendarIDs: [], eventStoreProvider: .macOSEventKit),
            events: EventDisplaySettings(
                showEventsForPeriod: .today,
                allDayEvents: .show,
                nonAllDayEvents: .show,
                declinedEventsAppearance: .strikethrough,
                pastEventsAppearance: .show_inactive,
                personalEventsAppearance: .show_active,
                showPendingEvents: .show,
                showTentativeEvents: .show,
                filterEventRegexes: [],
                dismissedEvents: [],
                ongoingEventVisibility: .showTenMinBeforeNext,
                showEventMaxTimeUntilEventEnabled: false,
                showEventMaxTimeUntilEventThreshold: 60
            ),
            statusBar: StatusBarSettings(
                eventTitleFormat: .show,
                eventTimeFormat: .show,
                eventTitleIconFormat: .none,
                statusbarEventTitleLength: statusbarEventTitleLengthLimits.max,
                hideMeetingTitle: false,
                showEventEndTime: true
            ),
            menu: MenuSettings(
                showTimelineInMenu: true,
                shortenEventTitle: true,
                menuEventTitleLength: 50,
                showEventDetails: false,
                showMeetingServiceIcon: true,
                showEventCalendarColor: true,
                showMeetingPrepLinks: true,
                hideFinishedEventsInMenu: true,
                eventActionHighlightMinutes: 2,
                showRemindersInMenu: false,
                remindersIncludeOverdue: true,
                showMeetingControlInMenu: true,
                showAgendaInMenu: true,
                showJoinSectionInMenu: true,
                showBookmarksInMenu: true,
                showCalendarInMenu: false,
                showUpNextInMenu: true
            ),
            notifications: NotificationSettings(
                joinEventNotification: true,
                joinEventNotificationTime: .atStart,
                endOfEventNotification: true,
                endOfEventNotificationTime: .atEnd,
                fullscreenNotification: false,
                fullscreenNotificationTime: .atStart,
                fullscreenNotificationsForEventsWithoutMeetingLink: false
            ),
            meetings: MeetingSettings(
                createMeetingService: .zoom,
                createMeetingServiceUrl: "",
                bookmarks: [],
                browsers: [],
                defaultBrowser: Browser(
                    name: "Default Browser", path: "", arguments: "", deletable: false),
                browserForCreateMeeting: systemDefaultBrowser,
                providerBrowsers: [:],
                providerOpeningModes: [:]
            ),
            advanced: AdvancedSettings(
                automaticEventJoin: false,
                automaticEventJoinTime: .atStart,
                runJoinEventScript: false,
                joinEventScriptLocation: nil,
                joinEventScript: "",
                runEventStartScript: false,
                eventStartScriptLocation: nil,
                eventStartScriptTime: .atStart,
                eventStartScript: eventStartScriptPlaceholder,
                customRegexes: []
            )
        )
    }
}

// MARK: - Defaults write boundary

extension AppSettings {
    @MainActor
    static func setEventStoreProvider(_ provider: EventStoreProvider) {
        migrateSelectedCalendarsByProviderIfNeeded()
        Defaults[.eventStoreProvider] = provider
        Defaults[.selectedCalendarIDs] = selectedCalendarIDs(for: provider)
    }

    @MainActor
    static func clearSelectedCalendars() {
        migrateSelectedCalendarsByProviderIfNeeded()
        var selections = Defaults[.selectedCalendarIDsByProvider]
        selections[Defaults[.eventStoreProvider].rawValue] = []
        Defaults[.selectedCalendarIDsByProvider] = selections
        Defaults[.selectedCalendarIDs] = []
    }

    @MainActor
    static func toggleMeetingTitleVisibility() {
        Defaults[.eventTitleFormat] = Defaults[.eventTitleFormat] == .show ? .generic : .show
        Defaults[.hideMeetingTitle] = false
    }

    @MainActor
    static func setCalendarSelection(id: String, selected: Bool) {
        setCalendarSelection(provider: Defaults[.eventStoreProvider], id: id, selected: selected)
    }

    /// Ticks or unticks a calendar within the given provider's selection.
    ///
    /// Pass the calendar's own provider, not `Defaults[.eventStoreProvider]`,
    /// which names only the write-capable source.
    @MainActor
    static func setCalendarSelection(provider: EventStoreProvider, id: String, selected: Bool) {
        migrateSelectedCalendarsByProviderIfNeeded()
        let providerKey = provider.rawValue
        var selections = Defaults[.selectedCalendarIDsByProvider]
        var selectedIDs = selections[providerKey] ?? []

        if selected {
            if !selectedIDs.contains(id) {
                selectedIDs.append(id)
            }
        } else {
            selectedIDs.removeAll { $0 == id }
        }

        selections[providerKey] = selectedIDs
        Defaults[.selectedCalendarIDsByProvider] = selections
        // The legacy flat key mirrors only the primary provider's selection.
        if provider == Defaults[.eventStoreProvider] {
            Defaults[.selectedCalendarIDs] = selectedIDs
        }
    }

    @MainActor
    static func selectedCalendarIDs(for provider: EventStoreProvider) -> [String] {
        migrateSelectedCalendarsByProviderIfNeeded()
        return Defaults[.selectedCalendarIDsByProvider][provider.rawValue] ?? []
    }

    // MARK: - Connected sources

    /// The connected sources this build can reach.
    /// Use this, not `Defaults[.eventStoreProvider]`, to find where events come from.
    @MainActor
    static func enabledCalendarSources() -> CalendarSourceSelection {
        migrateEnabledCalendarSourcesIfNeeded()
        return CalendarSourceSelection(providers: Defaults[.enabledCalendarSources]).usable
    }

    /// Persists a new source selection.
    ///
    /// Also points `eventStoreProvider` at the write-capable source (EventKit when connected),
    /// otherwise the first selected source, and refreshes the legacy flat selection mirror.
    @MainActor
    static func setEnabledCalendarSources(_ selection: CalendarSourceSelection) {
        migrateEnabledCalendarSourcesIfNeeded()
        let stored = selection.providers
        Defaults[.enabledCalendarSources] = stored
        let primary = selection.writeSource?.provider ?? stored.first ?? .macOSEventKit
        Defaults[.eventStoreProvider] = primary
        Defaults[.selectedCalendarIDs] = selectedCalendarIDs(for: primary)
    }

    /// Records the connected set without touching the primary provider or the
    /// legacy flat selection mirror, unlike `setEnabledCalendarSources`.
    @MainActor
    static func recordEnabledCalendarSources(_ selection: CalendarSourceSelection) {
        Defaults[.enabledCalendarSources] = selection.providers
        Defaults[.enabledCalendarSourcesMigrated] = true
    }

    /// One-time seed of the multi-source key from the install's single legacy provider.
    @MainActor
    static func migrateEnabledCalendarSourcesIfNeeded() {
        guard !Defaults[.enabledCalendarSourcesMigrated] else { return }

        if Defaults[.enabledCalendarSources].isEmpty {
            Defaults[.enabledCalendarSources] = CalendarSourceSelection
                .migrating(fromSingleProvider: Defaults[.eventStoreProvider].sourceKind)
                .providers
        }
        Defaults[.enabledCalendarSourcesMigrated] = true
    }

    @MainActor
    static func migrateSelectedCalendarsByProviderIfNeeded() {
        guard !Defaults[.selectedCalendarIDsByProviderMigrated] else { return }

        let providerKey = Defaults[.eventStoreProvider].rawValue
        var selections = Defaults[.selectedCalendarIDsByProvider]
        if selections[providerKey] == nil {
            selections[providerKey] = Defaults[.selectedCalendarIDs]
        }

        Defaults[.selectedCalendarIDsByProvider] = selections
        Defaults[.selectedCalendarIDsByProviderMigrated] = true
    }

    @MainActor
    static func completeOnboarding() {
        Defaults[.onboardingCompleted] = true
    }

    @MainActor
    static func acknowledgeCurrentChangelog() {
        Defaults[.lastRevisedVersionInChangelog] = Defaults[.appVersion]
    }

    @MainActor
    static func dismissEvent(_ event: MBEvent) {
        dismissEvent(
            ProcessedEvent(
                id: event.id,
                lastModifiedDate: event.lastModifiedDate,
                eventEndDate: event.endDate
            )
        )
    }

    @MainActor
    static func dismissEvent(_ event: ProcessedEvent) {
        Defaults[.dismissedEvents].append(event)
    }

    @MainActor
    static func undismissEvent(id: String) {
        Defaults[.dismissedEvents].removeAll { $0.id == id }
    }

    @MainActor
    static func clearDismissedEvents() {
        Defaults[.dismissedEvents] = []
    }

    @MainActor
    static func replaceDismissedEvents(_ events: [ProcessedEvent]) {
        Defaults[.dismissedEvents] = events
    }

    @MainActor
    static func refreshDismissedEvents(using currentEvents: [MBEvent]) {
        let dismissedEvents: [ProcessedEvent] = Defaults[.dismissedEvents].compactMap { dismissedEvent in
            guard
                let event = currentEvents.first(where: { $0.id == dismissedEvent.id }),
                event.endDate.timeIntervalSinceNow > 0
            else {
                return nil
            }

            // Keep the dismissal-time lastModifiedDate: it is what re-surfaces a dismissed event after it changes.
            return ProcessedEvent(
                id: dismissedEvent.id,
                lastModifiedDate: dismissedEvent.lastModifiedDate,
                eventEndDate: event.endDate
            )
        }

        replaceDismissedEvents(dismissedEvents)
    }
}
