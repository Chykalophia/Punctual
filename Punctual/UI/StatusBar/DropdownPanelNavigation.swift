//
//  DropdownPanelNavigation.swift
//  Punctual
//
//  Hostless keyboard-navigation model for the dropdown panel: the ordered list
//  of interactive rows and arrow-key stepping over it.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// Which agenda section a row belongs to. Each section caps and expands independently.
enum AgendaDay: Hashable {
    case today
    case tomorrow
}

/// One keyboard-reachable row of the dropdown panel, identified by what it acts
/// on rather than by index, so a selection survives a reorder.
enum DropdownPanelRow: Hashable {
    /// The next/current meeting summary card.
    case meetingSummary(String)
    /// The agenda's "+N more" row; selecting it reveals the capped events in place.
    case showMoreEvents(AgendaDay)
    /// The meeting module's repair/refresh row, shown instead of the card when
    /// there is no meeting to display.
    case emptyStateAction
    /// An agenda event row (today or tomorrow), by event id.
    case event(String)
    /// A reminder row, by reminder id.
    case reminder(String)
    /// The join module's "Join next/current meeting" row, by event id.
    case joinNext(String)
    /// The join module's "Create meeting" row.
    case createMeeting
    /// A bookmark row, by index into the stored bookmark list.
    case bookmark(Int)
    /// The pinned footer's "What's new?" row (only when the changelog is unread).
    case whatsNew
    case preferences
    case quit
}

/// Which way an arrow key moves the selection.
enum DropdownPanelMoveDirection {
    case up
    case down
}

/// What the panel is rendering: the visible modules in order plus the
/// identifiers inside each.
struct DropdownPanelContent: Equatable {
    /// The visible modules, already resolved by `DropdownCompositionPolicy` and
    /// filtered to the ones with content.
    var modules: [DropdownModule] = []
    /// The event shown in the meeting-control card, when there is one.
    var meetingEventID: String?
    /// Only the events actually rendered, after the row cap.
    var todayEventIDs: [String] = []
    var reminderIDs: [String] = []
    var tomorrowEventIDs: [String] = []
    /// Whether each section shows a "+N more" row.
    var todayHasHiddenEvents: Bool = false
    var tomorrowHasHiddenEvents: Bool = false
    /// The event the join module's "Join …" row would join, when present.
    var joinNextEventID: String?
    var bookmarkCount: Int = 0
    /// Whether the pinned footer shows the "What's new?" row.
    var showsWhatsNew: Bool = false
}

enum DropdownPanelNavigation {
    /// The interactive rows the panel renders, in visual order: the modules, then
    /// the pinned footer.
    static func interactiveRows(for content: DropdownPanelContent) -> [DropdownPanelRow] {
        var rows: [DropdownPanelRow] = []

        for module in content.modules {
            switch module {
            case .greeting, .timeline, .calendar:
                // Not arrow-key reachable. The calendar grid keeps its own mouse
                // targets; a two-direction list model cannot address a grid.
                continue
            case .meeting:
                rows.append(
                    content.meetingEventID.map(DropdownPanelRow.meetingSummary) ?? .emptyStateAction
                )
            case .agenda:
                // Each "+N more" row sits directly under the events it unfolds.
                rows += content.todayEventIDs.map(DropdownPanelRow.event)
                if content.todayHasHiddenEvents { rows.append(.showMoreEvents(.today)) }
                rows += content.reminderIDs.map(DropdownPanelRow.reminder)
                rows += content.tomorrowEventIDs.map(DropdownPanelRow.event)
                if content.tomorrowHasHiddenEvents { rows.append(.showMoreEvents(.tomorrow)) }
            case .join:
                if let joinNextEventID = content.joinNextEventID {
                    rows.append(.joinNext(joinNextEventID))
                }
                rows.append(.createMeeting)
            case .bookmarks:
                rows += (0..<max(0, content.bookmarkCount)).map(DropdownPanelRow.bookmark)
            }
        }

        if content.showsWhatsNew { rows.append(.whatsNew) }
        rows.append(.preferences)
        rows.append(.quit)
        return rows
    }

    /// The selection index after one arrow-key step, clamped at both ends (no wrap).
    ///
    /// With no current selection, Down selects the first row and Up the last. An
    /// out-of-range `current` snaps back into bounds without stepping.
    /// - Returns: `nil` only when `count` is zero.
    static func next(
        from current: Int?,
        direction: DropdownPanelMoveDirection,
        count: Int
    ) -> Int? {
        guard count > 0 else { return nil }
        guard let current else {
            return direction == .down ? 0 : count - 1
        }
        let clamped = min(max(current, 0), count - 1)
        guard clamped == current else { return clamped }
        let step = direction == .down ? 1 : -1
        return min(max(clamped + step, 0), count - 1)
    }
}
