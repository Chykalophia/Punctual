//
//  StatusBarPresentation+Punctual.swift
//  MeetingBar
//

import Defaults
import Foundation

extension StatusBarPresentationSettings {
    /// The `Defaults` the menu bar's mode policy reads.
    static var current: StatusBarPresentationSettings {
        StatusBarPresentationSettings(
            hasSelectedCalendars: !CalendarSourceSelection.connectedSelectedCalendarIDs().isEmpty,
            showEventMaxTimeUntilEventEnabled: Defaults[.showEventMaxTimeUntilEventEnabled],
            showEventMaxTimeUntilEventThreshold: Defaults[.showEventMaxTimeUntilEventThreshold],
            highlightImminentEvent: Defaults[.menuBarHighlightImminentEvent],
            imminentLeadMinutes: Defaults[.eventActionHighlightMinutes]
        )
    }
}

extension StatusBarTimeDisplay {
    init(_ format: EventTimeFormat) {
        switch format {
        case .show:
            self = .show
        case .show_under_title:
            self = .showUnderTitle
        case .hide:
            self = .hide
        }
    }
}

extension StatusBarEventParticipation {
    init(_ status: MBEventAttendeeStatus) {
        switch status {
        case .pending:
            self = .pending
        case .tentative:
            self = .tentative
        default:
            self = .normal
        }
    }
}

extension StatusBarParticipationDisplay {
    init(_ pendingAppearance: PendingEventsAppereance) {
        switch pendingAppearance {
        case .show_inactive:
            self = .inactive
        case .show_underlined:
            self = .underlined
        case .show, .hide:
            self = .normal
        }
    }

    init(_ tentativeAppearance: TentativeEventsAppereance) {
        switch tentativeAppearance {
        case .show_inactive:
            self = .inactive
        case .show_underlined:
            self = .underlined
        case .show, .hide:
            self = .normal
        }
    }
}

extension StatusBarEventPresentationInput {
    init(_ event: MBEvent) {
        self.init(
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            meetingService: event.meetingLink?.service,
            participation: StatusBarEventParticipation(event.participationStatus),
            hasMeetingLink: event.meetingLink != nil
        )
    }
}

extension MenuBarJoinActionSettings {
    static var current: MenuBarJoinActionSettings {
        MenuBarJoinActionSettings(
            isEnabled: Defaults[.menuBarShowJoinAction],
            leadMinutes: Defaults[.menuBarJoinActionLeadMinutes],
            label: "notifications_meetingbar_join_event_action".loco()
        )
    }
}

extension StatusBarPresenterSettings {
    static var current: StatusBarPresenterSettings {
        StatusBarPresenterSettings(
            presentation: .current,
            title: .current,
            timeDisplay: StatusBarTimeDisplay(Defaults[.eventTimeFormat]),
            iconFormat: StatusBarIconFormat(Defaults[.eventTitleIconFormat]),
            iconFormatAssetName: Defaults[.eventTitleIconFormat].rawValue,
            iconAssets: .production,
            pendingDisplay: StatusBarParticipationDisplay(Defaults[.showPendingEvents]),
            tentativeDisplay: StatusBarParticipationDisplay(Defaults[.showTentativeEvents])
        )
    }
}

// MARK: - Title policy adapters

extension StatusBarEventTitleFormat {
    init(_ format: EventTitleFormat) {
        switch format {
        case .show: self = .show
        case .generic: self = .generic
        case .dot: self = .dot
        case .none: self = .none
        }
    }
}

extension StatusBarTitleLabels {
    static var current: StatusBarTitleLabels {
        StatusBarTitleLabels(
            genericMeetingTitle: "general_meeting".loco(),
            noTitle: "status_bar_no_title".loco(),
            activeEventTimeFormat: "status_bar_event_status_now".loco(),
            upcomingEventTimeFormat: "status_bar_event_status_in".loco()
        )
    }
}

extension StatusBarTitleSettings {
    static var current: StatusBarTitleSettings {
        StatusBarTitleSettings(
            titleFormat: StatusBarEventTitleFormat(Defaults[.eventTitleFormat]),
            titleLength: Defaults[.statusbarEventTitleLength],
            labels: .current
        )
    }
}

// MARK: - Icon policy adapters

extension StatusBarIconFormat {
    /// Maps the stored `EventTitleIconFormat` to the hostless mirror.
    init(_ format: EventTitleIconFormat) {
        switch format {
        case .calendar: self = .calendar
        case .appicon: self = .appicon
        case .eventtype: self = .eventtype
        case .none: self = .none
        }
    }
}

extension StatusBarIconAssets {
    /// Asset names from `MenuStyleConstants`.
    static var production: StatusBarIconAssets {
        StatusBarIconAssets(
            appIcon: MenuStyleConstants.appIconName,
            calendarCheckmark: MenuStyleConstants.calendarCheckmarkIconName,
            calendar: MenuStyleConstants.calendarIconName
        )
    }
}

// MARK: - Composable menu bar adapters

extension MenuBarComposition {
    /// The user's saved composition, or `nil` when the classic
    /// `StatusBarPresenter` path should draw the menu bar instead.
    ///
    /// An empty token list means "classic path" before
    /// `MenuBarTimeFormatDefaultsMigration` has run, and "every block off" after.
    static var currentIfEnabled: MenuBarComposition? {
        let tokens = MenuBarBlockList.kinds(stored: Defaults[.menuBarTokens])
        if tokens.isEmpty {
            return Defaults[.menuBarTimeFormatMigrated] ? MenuBarComposition(tokens: []) : nil
        }
        return MenuBarComposition(tokens: tokens)
    }

    /// A composition mirroring the user's classic status-bar settings, used to
    /// seed the token list during migration.
    static var derivedFromLegacy: MenuBarComposition {
        var tokens: [MenuBarTokenKind] = []
        if Defaults[.eventTitleIconFormat] != .none { tokens.append(.icon) }
        if Defaults[.eventTitleFormat] != .none { tokens.append(.title) }
        if Defaults[.eventTimeFormat] != .hide { tokens.append(.countdown) }
        return tokens.isEmpty ? .standard : MenuBarComposition(tokens: tokens)
    }
}

extension MenuBarComposedSettings {
    /// Snapshot of the `Defaults` the composed presenter needs.
    static var current: MenuBarComposedSettings {
        MenuBarComposedSettings(
            presentation: .current,
            title: .current,
            countdownStyle: CountdownStyle(rawValue: Defaults[.menuBarCountdownStyle]) ?? .full,
            countdownLeadMinutes: Defaults[.menuBarCountdownLeadMinutes],
            dateStyle: MenuBarDateStyle(rawValue: Defaults[.menuBarDateStyle]) ?? .medium,
            progressStyle: MenuBarProgressStyle(rawValue: Defaults[.menuBarProgressStyle]) ?? .day,
            use24HourClock: Defaults[.timeFormat] == .military,
            worldClockTimeZone: TimeZone(identifier: Defaults[.menuBarWorldClockTimeZone]) ?? .current,
            worldClockLabel: Defaults[.menuBarWorldClockLabel],
            weekNumberPrefix: "menu_bar_week_number_prefix".loco(),
            iconFormat: StatusBarIconFormat(Defaults[.eventTitleIconFormat]),
            iconFormatAssetName: Defaults[.eventTitleIconFormat].rawValue,
            iconAssets: .production,
            tokenSeparator: "  ",
            pendingDisplay: StatusBarParticipationDisplay(Defaults[.showPendingEvents]),
            tentativeDisplay: StatusBarParticipationDisplay(Defaults[.showTentativeEvents]),
            twoLines: Defaults[.menuBarTwoLineLayout],
            joinAction: .current
        )
    }
}
