//
//  CalendarGridNavigation.swift
//  Punctual
//
//  Arrow-key travel across a calendar grid: where the selection lands, and
//  whether the grid has to page to keep it visible.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// Where a move landed, and what the grid must do about it.
public struct CalendarGridNavigationResult: Equatable, Sendable {
    /// The newly selected day, normalised to the start of that day.
    public let selectedDay: Date
    /// Whether the selection left the visible range; the caller decides how to re-anchor.
    public let requiresPaging: Bool

    public init(selectedDay: Date, requiresPaging: Bool) {
        self.selectedDay = selectedDay
        self.requiresPaging = requiresPaging
    }
}

public enum CalendarGridNavigation {
    /// Day deltas for the arrow keys: ±1 for left and right, ±7 (one grid row) for up and down.
    public static let previousDay = -1
    public static let nextDay = 1
    public static let previousWeek = -7
    public static let nextWeek = 7

    /// Moves the selection by `days`, reporting whether the grid must re-anchor.
    ///
    /// - Parameters:
    ///   - selectedDay: The current selection, or the grid's anchor day when nothing is selected.
    ///   - visibleRange: The inclusive first and last day drawn, including adjacent-month padding days.
    public static func move(
        from selectedDay: Date,
        byDays days: Int,
        visibleRange: (start: Date, end: Date),
        calendar: Calendar
    ) -> CalendarGridNavigationResult {
        let current = calendar.startOfDay(for: selectedDay)
        guard let moved = calendar.date(byAdding: .day, value: days, to: current) else {
            return CalendarGridNavigationResult(selectedDay: current, requiresPaging: false)
        }
        let landed = calendar.startOfDay(for: moved)

        let first = calendar.startOfDay(for: visibleRange.start)
        let last = calendar.startOfDay(for: visibleRange.end)
        let isVisible = landed >= first && landed <= last

        return CalendarGridNavigationResult(selectedDay: landed, requiresPaging: !isVisible)
    }
}
