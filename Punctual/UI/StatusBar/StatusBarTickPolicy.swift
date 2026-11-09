//
//  StatusBarTickPolicy.swift
//  Punctual
//
//  Hostless schedule for time-driven redraws of the status bar and dropdown:
//  minute boundaries plus event start/end transitions.
//

import Foundation

enum StatusBarTickPolicy {
    /// Maximum seconds between redraws.
    static let maximumInterval: TimeInterval = 60

    /// Instants at which the menu bar's rendered state changes for one meeting:
    /// its start, its end, and start plus `ongoingGracePeriod` when given.
    ///
    /// Unsorted; pass to `nextFireDate(now:transitions:)`.
    static func transitionDates(
        eventStart: Date?,
        eventEnd: Date?,
        ongoingGracePeriod: TimeInterval?
    ) -> [Date] {
        var dates: [Date] = []
        if let eventStart {
            dates.append(eventStart)
            if let ongoingGracePeriod {
                dates.append(eventStart.addingTimeInterval(ongoingGracePeriod))
            }
        }
        if let eventEnd {
            dates.append(eventEnd)
        }
        return dates
    }

    /// One rendered row's start and end.
    struct EventBoundary: Hashable, Sendable {
        let start: Date
        let end: Date

        init(start: Date, end: Date) {
            self.start = start
            self.end = end
        }
    }

    /// Transitions for a whole rendered agenda: every row's start and end, plus
    /// end + `hideFinishedAfter` when finished rows are hidden.
    ///
    /// Unsorted; pass to `nextFireDate(now:transitions:)`.
    static func transitionDates(
        boundaries: [EventBoundary],
        hideFinishedAfter: TimeInterval? = nil
    ) -> [Date] {
        boundaries.flatMap { boundary -> [Date] in
            var dates = [boundary.start, boundary.end]
            if let hideFinishedAfter {
                dates.append(boundary.end.addingTimeInterval(hideFinishedAfter))
            }
            return dates
        }
    }

    /// The next redraw instant: the earliest future transition or the next
    /// wall-clock minute boundary, capped at `maximumInterval` from `now`.
    static func nextFireDate(
        now: Date,
        transitions: [Date],
        calendar: Calendar = .current
    ) -> Date {
        let ceiling = now.addingTimeInterval(maximumInterval)
        let candidates = transitions.filter { $0 > now } + [nextMinuteBoundary(after: now, calendar: calendar)]
        let earliest = candidates.min() ?? ceiling
        return min(earliest, ceiling)
    }

    /// The start of the next wall-clock minute, or `now + maximumInterval` if
    /// the calendar cannot resolve it.
    static func nextMinuteBoundary(after now: Date, calendar: Calendar = .current) -> Date {
        guard let boundary = calendar.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) else {
            return now.addingTimeInterval(maximumInterval)
        }
        return boundary
    }

    /// Seconds to wait before the next redraw, never less than 0.5 so the timer
    /// cannot spin.
    static func delay(now: Date, until fireDate: Date) -> TimeInterval {
        max(0.5, fireDate.timeIntervalSince(now))
    }
}
