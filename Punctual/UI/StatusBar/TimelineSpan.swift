//
//  TimelineSpan.swift
//  Punctual
//
//  Hostless model for the dropdown's timeline bar: span, appearance, and the
//  date range it draws.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// What span the timeline draws, or `off` for none.
public enum TimelineSpan: String, CaseIterable, Codable, Hashable, Sendable {
    /// Not drawn.
    case off
    /// A window around now; the now-marker stays near the leading side.
    case relative
    /// The working day end to end; the now-marker moves across it.
    case day

    public var isVisible: Bool { self != .off }
}

/// How the timeline is drawn. Independent of `TimelineSpan`.
public enum TimelineAppearance: String, CaseIterable, Codable, Hashable, Sendable {
    /// Hour grid with labels above; overlapping meetings stack into rows. Tallest.
    case track
    /// One rail with meetings inline and hour labels beneath; overlaps flatten.
    case bar
    /// The rail alone, no labels.
    case minimal

    /// Whether hour labels are drawn.
    public var showsHourLabels: Bool { self != .minimal }

    /// `track` stacks overlapping meetings; the others flatten them onto one line.
    public var stacksOverlaps: Bool { self == .track }
}

/// Decisions for `DropdownModuleMergeMigration`, which maps the retired `upNext`
/// module and `showTimelineInMenu` toggle onto their replacements.
public enum DropdownModuleMergePolicy {
    /// The countdown bar is on if the user had the up-next card.
    public static func showsProgress(hadUpNextModule: Bool) -> Bool { hadUpNextModule }

    /// A hidden timeline becomes `.off`; a shown one keeps the stored span.
    public static func timelineStyle(
        wasVisible: Bool,
        stored: TimelineSpan
    ) -> TimelineSpan {
        wasVisible ? stored : .off
    }
}

public enum DayTimelineRange {
    /// Window ahead of and behind `now` for `.relative`.
    public static let relativeLookBehind: TimeInterval = 3 * 3600
    public static let relativeLookAhead: TimeInterval = 6 * 3600

    /// The narrowest span the timeline may draw.
    public static let minimumRelativeSpan: TimeInterval = 4 * 3600

    /// Past and future the relative window always shows around now.
    public static let minimumLookBehind: TimeInterval = 3600
    public static let minimumLookAhead: TimeInterval = 2 * 3600

    /// Hours the `.day` style covers when the day holds nothing unusual.
    public static let dayStartHour = 8
    public static let dayEndHour = 20

    /// The span the bar draws.
    ///
    /// - Parameter bounds: The earliest start and latest end among the events
    ///   being drawn, or `nil` when there are none.
    public static func range(
        style: TimelineSpan,
        now: Date,
        bounds: (first: Date, last: Date)?,
        calendar: Calendar = .current
    ) -> ClosedRange<Date> {
        switch style {
        // `.off` is never drawn; it shares `.relative` only to keep the switch total.
        case .off, .relative: relativeRange(now: now, bounds: bounds)
        case .day: dayRange(now: now, bounds: bounds, calendar: calendar)
        }
    }

    /// A window around now, tightened to the events on the bar (with a 15-minute
    /// margin) but never wider than `relativeLookBehind`/`relativeLookAhead`,
    /// never inside the minimum look-behind/ahead, and at least `minimumRelativeSpan`.
    private static func relativeRange(
        now: Date,
        bounds: (first: Date, last: Date)?
    ) -> ClosedRange<Date> {
        let widestLower = now.addingTimeInterval(-relativeLookBehind)
        let widestUpper = now.addingTimeInterval(relativeLookAhead)
        guard let bounds else { return widestLower...widestUpper }

        let margin: TimeInterval = 15 * 60
        let lower = min(
            max(bounds.first.addingTimeInterval(-margin), widestLower),
            now.addingTimeInterval(-minimumLookBehind)
        )
        let upper = max(
            min(bounds.last.addingTimeInterval(margin), widestUpper),
            now.addingTimeInterval(minimumLookAhead)
        )
        return lower...max(upper, lower.addingTimeInterval(minimumRelativeSpan))
    }

    /// `dayStartHour` to `dayEndHour`, widened to include the events and now.
    private static func dayRange(
        now: Date,
        bounds: (first: Date, last: Date)?,
        calendar: Calendar
    ) -> ClosedRange<Date> {
        let startOfDay = calendar.startOfDay(for: now)
        let defaultLower = calendar.date(
            byAdding: .hour, value: dayStartHour, to: startOfDay
        ) ?? startOfDay
        let defaultUpper = calendar.date(
            byAdding: .hour, value: dayEndHour, to: startOfDay
        ) ?? startOfDay.addingTimeInterval(24 * 3600)

        var lower = min(defaultLower, bounds?.first ?? defaultLower)
        var upper = max(defaultUpper, bounds?.last ?? defaultUpper)
        lower = min(lower, now)
        upper = max(upper, now)
        return lower...max(upper, lower.addingTimeInterval(minimumRelativeSpan))
    }
}
