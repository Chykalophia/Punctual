//
//  AgendaSectionVisibility.swift
//  Punctual
//
//  Hostless policy deciding whether an agenda day section is drawn at all.
//  Per-event filtering (`DropdownEventVisibility`) is applied first.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

public enum AgendaSectionVisibilityPolicy {
    /// Whether to draw a day's section: its heading, separator, and empty-state line.
    ///
    /// The anchor day is always shown, even when empty and `hidesEmptyDays` is on,
    /// so the agenda never renders with no headings.
    ///
    /// - Parameters:
    ///   - eventCount: Events the section would draw after per-event filtering
    ///     (the rendered count, not the raw one).
    ///   - isIncludedByPeriod: Whether the user's look-ahead setting covers this day.
    ///     A day outside the period is hidden regardless of the other flags.
    ///   - hidesEmptyDays: The user's "hide empty days" preference.
    ///   - isAnchorDay: Whether this section is today.
    /// - Returns: `true` if the section should be drawn.
    public static func showsSection(
        eventCount: Int,
        isIncludedByPeriod: Bool,
        hidesEmptyDays: Bool,
        isAnchorDay: Bool
    ) -> Bool {
        guard isIncludedByPeriod else { return false }
        if isAnchorDay { return true }
        guard hidesEmptyDays else { return true }
        return eventCount > 0
    }
}
