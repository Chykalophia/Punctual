//
//  StatusBarMenuState.swift
//  MeetingBar
//

import Defaults
import Foundation

enum StatusBarProviderStatus: Equatable {
    case initializing
    case connected(lastRefresh: Date?)
    case authRequired(message: String?)
    case permissionRequired(message: String?)
    case stale(lastRefresh: Date?, message: String?)
    case refreshFailed(message: String?)
}

enum StatusBarEmptyStateReason: Equatable {
    case authRequired
    case permissionRequired
    /// The provider is connected but exposes no calendars to select.
    case noCalendarsAvailable
    case noCalendarsSelected
    case refreshFailed
    case noUpcomingMeetings
}

enum StatusBarProviderWarning: Equatable {
    case authRequired
    case permissionRequired
    case stale
    case refreshFailed
}

/// Value-typed snapshot of everything the status bar dropdown needs to render,
/// so views never read `Defaults` or singletons directly.
///
/// Built by `StatusBarMenuState.make(...)`. Must not import AppKit or UserNotifications.
struct StatusBarMenuState: Equatable {
    // MARK: - Events (split by day)

    var todayEvents: [MBEvent] = []
    var tomorrowEvents: [MBEvent] = []
    var nextEvent: MBEvent?

    // MARK: - Reminders

    /// Incomplete reminders due today (and optionally overdue), filtered and
    /// sorted. Empty unless reminders are enabled in settings.
    var todayReminders: [MBReminder] = []

    // MARK: - Provider

    var activeProvider: EventStoreProvider = .macOSEventKit
    var providerHealth = ProviderHealth()
    var providerStatus: StatusBarProviderStatus = .initializing
    var providerWarning: StatusBarProviderWarning?
    var emptyStateReason: StatusBarEmptyStateReason?
    var selectedCalendarIDs: [String] = []

    /// Number of calendars the active provider currently exposes.
    var availableCalendarCount: Int = 0

    // MARK: - Settings snapshot

    /// Full settings snapshot.
    var settings: AppSettings = .empty

    // MARK: - Pre-computed display flags

    /// Whether at least one selected calendar ID matches a currently available
    /// calendar. `false` when none are available or every selected ID is stale.
    var hasSelectedCalendars: Bool = false

    /// Whether more than one calendar is selected.
    var hasMultipleSelectedCalendars: Bool = false

    /// Whether the day-timeline bar should appear above the event list.
    var showTimeline: Bool = false

    // MARK: - Day-summary greeting header

    /// Summary for the greeting header; `nil` when unavailable.
    var daySummary: DaySummary?

    /// Resolved friendly first name for the greeting, or `nil` for a name-less one.
    var greetingName: String?

    /// The user's "show greeting header" preference.
    var showGreetingHeader: Bool = false

    /// Whether the greeting header renders: enabled, a usable calendar selected,
    /// and a summary present.
    var shouldShowGreetingHeader: Bool {
        showGreetingHeader && hasSelectedCalendars && daySummary != nil
    }

    /// Whether the timeline renders: enabled and at least one event today.
    var shouldShowTimeline: Bool {
        showTimeline && !todayEvents.isEmpty
    }

    /// Time format for event times. The default here is a placeholder; `make`
    /// fills it from `Defaults[.timeFormat]`.
    var timeFormat: TimeFormat = .military

    // MARK: - Changelog / install state

    /// Major-version prefix of the running app (e.g. "5.0").
    var appMajorVersion: String = ""

    /// Major-version prefix of the last release acknowledged in the changelog.
    /// Differs from `appMajorVersion` when the changelog is unread.
    var lastRevisedMajorVersion: String = ""

    // MARK: - Convenience accessors

    /// Shorthand accessors for settings groups.
    var events: EventDisplaySettings { settings.events }
    var statusBar: StatusBarSettings { settings.statusBar }
    var menu: MenuSettings { settings.menu }
    var meetings: MeetingSettings { settings.meetings }
}

// MARK: - Factory

@MainActor
extension StatusBarMenuState {
    static func make(
        from appState: AppState,
        settings: AppSettings = .current,
        now: Date = Date()
    ) -> StatusBarMenuState {
        makeSnapshot(
            appState: appState,
            settings: settings,
            now: now
        )
    }

    /// Builds a snapshot from `events` and the current settings. Reads `Defaults`.
    static func make(from events: [MBEvent]) -> StatusBarMenuState {
        let settings = AppSettings.current
        var appState = AppState()
        appState.events = events
        appState.activeProvider = settings.calendar.eventStoreProvider
        appState.selectedCalendarIDs = CalendarSourceSelection.connectedSelectedCalendarIDs()
        return makeSnapshot(
            appState: appState,
            settings: settings,
            now: Date()
        )
    }

    private static func makeSnapshot(
        appState: AppState,
        settings: AppSettings,
        now: Date
    ) -> StatusBarMenuState {
        let events = appState.events
        let activeProvider = appState.activeProvider
        let providerHealth = appState.providerHealth
        let selectedCalendarIDs = appState.selectedCalendarIDs
        let today = Calendar.current.startOfDay(for: now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let todayEvents = events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: today)
        }
        let tomorrowEvents = events.filter {
            Calendar.current.isDate($0.startDate, inSameDayAs: tomorrow)
        }

        let selectedCount = selectedCalendarIDs.count
        let availableCalendarIDs = appState.calendars.map(\.id)
        let availableCalendarCount = availableCalendarIDs.count
        let availableIDSet = Set(availableCalendarIDs)
        let hasUsableSelection = selectedCalendarIDs.contains { availableIDSet.contains($0) }
        let nextEvent = events.nextEvent(now: now)
        let providerStatus = providerStatus(
            provider: activeProvider,
            health: providerHealth
        )

        let todayReminders = settings.menu.showRemindersInMenu
            ? appState.reminders.dueToday(
                now: now,
                includeOverdue: settings.menu.remindersIncludeOverdue
            )
            : []

        let daySummary = DaySummaryPolicy.summary(
            input: DaySummaryInput(
                now: now,
                events: todayEvents.map {
                    DaySummaryInterval(start: $0.startDate, end: $0.endDate, isAllDay: $0.isAllDay)
                }
            ),
            calendar: Calendar.current
        )

        return StatusBarMenuState(
            todayEvents: todayEvents,
            tomorrowEvents: tomorrowEvents,
            nextEvent: nextEvent,
            todayReminders: todayReminders,
            activeProvider: activeProvider,
            providerHealth: providerHealth,
            providerStatus: providerStatus,
            providerWarning: providerWarning(for: providerStatus),
            emptyStateReason: emptyStateReason(
                providerStatus: providerStatus,
                availableCalendarCount: availableCalendarCount,
                hasUsableSelection: hasUsableSelection,
                hasUpcomingMeeting: nextEvent != nil
            ),
            selectedCalendarIDs: selectedCalendarIDs,
            availableCalendarCount: availableCalendarCount,
            settings: settings,
            hasSelectedCalendars: hasUsableSelection,
            hasMultipleSelectedCalendars: selectedCount > 1,
            showTimeline: settings.menu.showTimelineInMenu,
            daySummary: daySummary,
            greetingName: resolveGreetingName(),
            showGreetingHeader: Defaults[.showGreetingInMenu],
            timeFormat: Defaults[.timeFormat],
            appMajorVersion: majorMinorVersion(Defaults[.appVersion]),
            lastRevisedMajorVersion: majorMinorVersion(Defaults[.lastRevisedVersionInChangelog])
        )
    }

    /// The first word of the user's greeting-name override, else of
    /// `NSFullUserName()`; `nil` when both are blank.
    private static func resolveGreetingName() -> String? {
        let override = Defaults[.greetingName].trimmingCharacters(in: .whitespacesAndNewlines)
        let source = override.isEmpty ? NSFullUserName() : override
        let firstName = source.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        return firstName.isEmpty ? nil : firstName
    }

    /// The "major.minor" prefix of a dotted version string.
    static func majorMinorVersion(_ version: String) -> String {
        version.split(separator: ".").prefix(2).joined(separator: ".")
    }

    private static func providerStatus(
        provider: EventStoreProvider,
        health: ProviderHealth
    ) -> StatusBarProviderStatus {
        if health.authRequired {
            return .authRequired(message: health.lastErrorDescription)
        }
        if health.isStale {
            return .stale(
                lastRefresh: health.lastSuccessfulRefresh,
                message: health.lastErrorDescription
            )
        }
        if let error = health.lastErrorDescription {
            if provider == .macOSEventKit, health.lastSuccessfulRefresh == nil {
                return .permissionRequired(message: error)
            }
            return .refreshFailed(message: error)
        }
        if health.lastSuccessfulRefresh != nil {
            return .connected(lastRefresh: health.lastSuccessfulRefresh)
        }
        return .initializing
    }

    /// Why the meeting-control section is empty, or `nil` if it is not.
    /// Provider problems take precedence over calendar availability and selection.
    private static func emptyStateReason(
        providerStatus: StatusBarProviderStatus,
        availableCalendarCount: Int,
        hasUsableSelection: Bool,
        hasUpcomingMeeting: Bool
    ) -> StatusBarEmptyStateReason? {
        switch providerStatus {
        case .authRequired:
            return .authRequired
        case .permissionRequired:
            return .permissionRequired
        case .refreshFailed:
            return .refreshFailed
        case .initializing, .connected, .stale:
            break
        }

        if availableCalendarCount == 0 {
            return .noCalendarsAvailable
        }
        if !hasUsableSelection {
            return .noCalendarsSelected
        }
        if !hasUpcomingMeeting {
            return .noUpcomingMeetings
        }
        return nil
    }

    private static func providerWarning(
        for providerStatus: StatusBarProviderStatus
    ) -> StatusBarProviderWarning? {
        switch providerStatus {
        case .authRequired:
            .authRequired
        case .permissionRequired:
            .permissionRequired
        case .stale:
            .stale
        case .refreshFailed:
            .refreshFailed
        case .initializing, .connected:
            nil
        }
    }
}
