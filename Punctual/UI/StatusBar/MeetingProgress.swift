//
//  MeetingProgress.swift
//  Punctual
//
//  Hostless model for menu-bar meeting progress: how full the indicator is, what
//  phase it shows, and whether it is drawn at all.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// How the menu bar draws progress toward the next meeting.
///
/// Distinct from `MenuBarProgressStyle`, which selects what the `.progress` title
/// token measures (day or year).
public enum MeetingProgressStyle: String, CaseIterable, Codable, Hashable, Sendable {
    /// Draw nothing (the default).
    case none
    /// A thin rule under the whole item, filling left to right.
    case underline
    /// A ring around the icon.
    case ring
    /// A capsule around the whole item, filling left to right behind the text.
    case capsule
    /// A standalone mini-bar in the icon slot. The only style that adds menu-bar width.
    case bar

    /// Whether this style draws anything at all.
    public var drawsSomething: Bool { self != .none }

    /// Whether the style is drawn in the status item's image slot, replacing the
    /// icon, rather than as an overlay.
    public var occupiesImageSlot: Bool { self == .bar }
}

/// One frame of meeting progress, resolved and ready to draw.
public struct MeetingProgressPresentation: Equatable, Sendable {
    /// The meeting's phase relative to now. Colour is chosen by the renderer.
    public enum Phase: Equatable, Sendable {
        /// Approaching, but not yet worth reacting to.
        case upcoming
        /// Within the `leadMinutes` imminence threshold.
        case imminent
        /// The meeting is happening now; the indicator counts through it.
        case running
    }

    /// How full to draw, clamped to `0...1` on construction.
    public let fraction: Double
    public let phase: Phase

    public init(fraction: Double, phase: Phase) {
        self.fraction = min(max(fraction, 0), 1)
        self.phase = phase
    }
}

public enum MeetingProgressPolicy {
    /// How long before a meeting the indicator starts filling, in seconds.
    ///
    /// Deliberately independent of `eventActionHighlightMinutes`, whose short
    /// default would make the fill jump from empty to full.
    public static let leadWindow: TimeInterval = 3600

    /// The indicator for one meeting.
    ///
    /// Before the meeting, fills from 0 at `window` before start to exactly 1 at
    /// start; while running, fills again from start to end.
    ///
    /// - Parameters:
    ///   - leadMinutes: The imminence threshold (`eventActionHighlightMinutes`).
    ///   - window: Seconds before the start at which the fill begins.
    /// - Returns: `nil` when nothing should be drawn: outside the window, or ended.
    public static func presentation(
        start: Date,
        end: Date,
        now: Date,
        leadMinutes: Int,
        window: TimeInterval = leadWindow
    ) -> MeetingProgressPresentation? {
        if now >= start, now < end {
            let duration = end.timeIntervalSince(start)
            // Zero-length meetings occur in real calendars; avoid dividing by zero.
            guard duration > 0 else {
                return MeetingProgressPresentation(fraction: 1, phase: .running)
            }
            return MeetingProgressPresentation(
                fraction: now.timeIntervalSince(start) / duration,
                phase: .running
            )
        }

        guard now < start else { return nil }

        let untilStart = start.timeIntervalSince(now)
        guard untilStart <= window, window > 0 else { return nil }

        let fraction = (window - untilStart) / window
        let phase: MeetingProgressPresentation.Phase =
            untilStart <= TimeInterval(leadMinutes) * 60 ? .imminent : .upcoming
        return MeetingProgressPresentation(fraction: fraction, phase: phase)
    }
}
