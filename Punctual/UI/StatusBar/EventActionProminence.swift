//
//  EventActionProminence.swift
//  Punctual
//
//  Whether an event's action control (e.g. Join) renders as a call to action or
//  recessed. Shared by every surface that draws the control.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

enum EventActionProminence {
    /// Whether the meeting is running now or starts within `leadMinutes`.
    ///
    /// Styling only; the control stays clickable either way. An ended meeting is
    /// not imminent.
    ///
    /// - Parameter leadMinutes: Lead time in minutes; negatives are treated as zero.
    static func isImminent(
        start: Date,
        end: Date,
        now: Date,
        leadMinutes: Int
    ) -> Bool {
        if start <= now { return now < end }
        return start.timeIntervalSince(now) <= Double(max(0, leadMinutes)) * 60
    }
}
