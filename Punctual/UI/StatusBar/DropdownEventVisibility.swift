//
//  DropdownEventVisibility.swift
//  Punctual
//
//  Whether an event is shown in the dropdown at all, given the user's
//  hide/show settings, plus tomorrow's look-ahead rows and summary line.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

enum DropdownEventVisibility {
    /// Whether the dropdown draws `event`.
    ///
    /// - Parameter now: The panel's clock, used to decide "finished" and "past".
    static func shouldRender(
        _ event: MBEvent,
        menu: MenuSettings,
        events: EventDisplaySettings,
        isDeclined: Bool,
        now: Date
    ) -> Bool {
        if menu.hideFinishedEventsInMenu,
           !EventListWindow.isVisible(endDate: event.endDate, now: now) {
            return false
        }
        if isDeclined, events.declinedEventsAppearance == .hide {
            return false
        }
        if event.endDate < now, events.pastEventsAppearance == .hide {
            return false
        }
        if event.attendees.isEmpty, events.personalEventsAppearance == .hide {
            return false
        }
        return true
    }

    /// The tomorrow events the agenda renders, before the row cap.
    ///
    /// Per `display.showEventsForPeriod`: all visible events, only the first, or
    /// none (summary mode, where `tomorrowSummaryText` replaces the rows).
    static func tomorrowRendered(
        _ events: [MBEvent],
        menu: MenuSettings,
        display: EventDisplaySettings,
        isDeclined: (MBEvent) -> Bool,
        now: Date
    ) -> [MBEvent] {
        let period = display.showEventsForPeriod
        guard period.includesTomorrow else { return [] }
        let visible = visible(
            events,
            menu: menu,
            display: display,
            isDeclined: isDeclined,
            now: now
        )
        switch period {
        case .today_n_tomorrow: return visible
        case .today_n_tomorrow_next: return Array(visible.prefix(1))
        default: return []
        }
    }

    /// The one-line summary that replaces tomorrow's rows in summary mode.
    ///
    /// - Parameter events: The full visible list (not the rendered one), since the
    ///   line counts the meetings it stands in for.
    static func tomorrowSummaryText(visibleTomorrowEvents events: [MBEvent]) -> String {
        let title = "status_bar_section_tomorrow".loco()
        guard !events.isEmpty else {
            return "status_bar_section_date_nothing".loco(title.lowercased())
        }
        // Manual `_one`/`_other` plural split; these keys are not stringsdict plurals.
        let key = events.count == 1
            ? "status_bar_tomorrow_summary_one"
            : "status_bar_tomorrow_summary_other"
        return key.loco(
            events.count,
            events.first?.startDate.formatted(date: .omitted, time: .shortened) ?? ""
        )
    }

    /// The events the dropdown draws, in start order.
    static func visible(
        _ events: [MBEvent],
        menu: MenuSettings,
        display: EventDisplaySettings,
        isDeclined: (MBEvent) -> Bool,
        now: Date
    ) -> [MBEvent] {
        events
            .filter {
                shouldRender(
                    $0,
                    menu: menu,
                    events: display,
                    isDeclined: isDeclined($0),
                    now: now
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }
}
