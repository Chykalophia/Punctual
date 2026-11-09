//
//  DebugHarness.swift
//  Punctual
//
//  DEBUG-only control panel that feeds the running app synthetic meetings, so every
//  menu bar and dropdown state is one click away. Opened by `punctual://debug-harness`
//  (matched ahead of the router) or the status item's right-click menu.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

#if DEBUG
import AppKit

/// One canned situation to put the app in. `build` receives the time it is applied,
/// so a scenario ages in real time rather than freezing the clock.
struct DebugScenario: Identifiable, Sendable {
    let id: String
    let name: String
    /// One line on what this is for — shown under the button.
    let detail: String
    /// `nil` means stop overriding and use the real calendar.
    let build: (@Sendable (Date) -> [MBEvent])?

    static let all: [DebugScenario] = [
        DebugScenario(
            id: "real",
            name: "Real calendar",
            detail: "Drop the override and go back to actual events.",
            build: nil
        ),
        DebugScenario(
            id: "empty",
            name: "Nothing upcoming",
            detail: "Empty list — the done-for-today icon.",
            build: { _ in [] }
        ),
        DebugScenario(
            id: "far",
            name: "In 45 minutes",
            detail: "Ordinary upcoming meeting. No chip, no emphasis.",
            build: { now in [Self.meeting(now: now, startsIn: 45 * 60)] }
        ),
        DebugScenario(
            id: "evening",
            name: "In 3h 40m",
            detail: "Far out: with a countdown lead set, the name shows but the countdown does not.",
            build: { now in
                [Self.meeting(
                    now: now,
                    startsIn: 3 * 3600 + 40 * 60,
                    lasts: 45 * 60,
                    title: "Journalling",
                    hasLink: false
                )]
            }
        ),
        DebugScenario(
            id: "soon",
            name: "In 5 minutes",
            detail: "Close, but outside the default 2-minute chip window.",
            build: { now in [Self.meeting(now: now, startsIn: 5 * 60)] }
        ),
        DebugScenario(
            id: "chip",
            name: "In 90 seconds",
            detail: "Inside the chip window: Join appears, title boldens.",
            build: { now in [Self.meeting(now: now, startsIn: 90)] }
        ),
        DebugScenario(
            id: "seconds",
            name: "In 20 seconds",
            detail: "Watch it roll over into a running meeting.",
            build: { now in [Self.meeting(now: now, startsIn: 20)] }
        ),
        DebugScenario(
            id: "running",
            name: "Running now",
            detail: "Started 10 minutes ago, 20 to go. Chip stays up.",
            build: { now in [Self.meeting(now: now, startsIn: -10 * 60, lasts: 30 * 60)] }
        ),
        DebugScenario(
            id: "ending",
            name: "Ending in 90 seconds",
            detail: "Late in a meeting — progress indicator nearly full.",
            build: { now in [Self.meeting(now: now, startsIn: -28 * 60 - 30, lasts: 30 * 60)] }
        ),
        DebugScenario(
            id: "nolink",
            name: "In 90 seconds, no link",
            detail: "Chip must NOT appear — there is nowhere to join.",
            build: { now in [Self.meeting(now: now, startsIn: 90, hasLink: false)] }
        ),
        DebugScenario(
            id: "declined",
            name: "In 90 seconds, declined",
            detail: "Dimmed or struck per Filters; never boldened.",
            build: { now in [Self.meeting(now: now, startsIn: 90, participation: .declined)] }
        ),
        DebugScenario(
            id: "pending",
            name: "In 90 seconds, not answered",
            detail: "Pending appearance, and no bold emphasis.",
            build: { now in [Self.meeting(now: now, startsIn: 90, participation: .pending)] }
        ),
        DebugScenario(
            id: "tentative",
            name: "In 90 seconds, tentative",
            detail: "Tentative appearance from the Filters pane.",
            build: { now in [Self.meeting(now: now, startsIn: 90, participation: .tentative)] }
        ),
        DebugScenario(
            id: "long",
            name: "In 90 seconds, very long title",
            detail: "Exercises truncation with the chip still on the end.",
            build: { now in
                [Self.meeting(
                    now: now,
                    startsIn: 90,
                    title: "Quarterly cross-functional planning and roadmap alignment review "
                        + "with the extended leadership group"
                )]
            }
        ),
        DebugScenario(
            id: "allday",
            name: "All-day event",
            detail: "All-day handling in the menu bar and agenda.",
            build: { now in [Self.allDay(now: now)] }
        ),
        DebugScenario(
            id: "busy",
            name: "A busy day",
            detail: "Eight meetings across today — agenda density, +N more row.",
            build: { now in Self.busyDay(now: now) }
        )
    ]

    // MARK: - Builders

    /// A Google Meet URL the detector classifies, but which joins nothing real.
    static let meetingURL = URL(string: "https://meet.google.com/dbg-test-000")!

    private static let calendar = MBCalendar(
        title: "Debug harness",
        id: "debug-harness",
        source: "Debug",
        email: "debug@example.com",
        color: .systemPurple
    )

    static func meeting(
        now: Date,
        startsIn: TimeInterval,
        lasts: TimeInterval = 30 * 60,
        title: String = "Debug meeting",
        hasLink: Bool = true,
        participation: MBEventAttendeeStatus = .accepted,
        id: String = "debug-event"
    ) -> MBEvent {
        var event = MBEvent(
            id: id,
            lastModifiedDate: now,
            title: title,
            status: .confirmed,
            notes: nil,
            location: nil,
            url: hasLink ? meetingURL : nil,
            organizer: MBEventOrganizer(email: "debug@example.com", name: "Debug harness"),
            startDate: now.addingTimeInterval(startsIn),
            endDate: now.addingTimeInterval(startsIn + lasts),
            isAllDay: false,
            recurrent: false,
            calendar: calendar
        )
        // Set after init so the harness need not synthesize attendees.
        event.participationStatus = participation
        return event
    }

    static func allDay(now: Date) -> MBEvent {
        let startOfDay = Calendar.current.startOfDay(for: now)
        return MBEvent(
            id: "debug-all-day",
            lastModifiedDate: now,
            title: "Debug all-day event",
            status: .confirmed,
            notes: nil,
            location: nil,
            url: nil,
            organizer: nil,
            startDate: startOfDay,
            endDate: startOfDay.addingTimeInterval(24 * 60 * 60),
            isAllDay: true,
            recurrent: false,
            calendar: calendar
        )
    }

    static func busyDay(now: Date) -> [MBEvent] {
        // One imminent meeting, so the chip is up, plus seven later today.
        let offsets: [TimeInterval] = [90, 40 * 60, 75 * 60, 110 * 60, 150 * 60, 200 * 60, 260 * 60, 320 * 60]
        return offsets.enumerated().map { index, offset in
            meeting(
                now: now,
                startsIn: offset,
                lasts: 25 * 60,
                title: "Debug meeting \(index + 1)",
                id: "debug-busy-\(index)"
            )
        }
    }
}

/// What the menu bar is drawing right now, for the harness readout.
struct DebugRenderSummary {
    var firstLine: String
    var secondLine: String
    var actionLabel: String
    var chipRect: CGRect?
    var buttonWidth: CGFloat
    var eventCount: Int
    var isOverridden: Bool
    /// Whether any calendar is selected. With none, the status item stays idle
    /// whatever events are injected.
    var hasSelectedCalendars: Bool
}

/// Closures the harness drives the app through.
struct DebugHarnessHandlers {
    var apply: (DebugScenario) -> Void = { _ in }
    var summary: () -> DebugRenderSummary = {
        DebugRenderSummary(
            firstLine: "", secondLine: "", actionLabel: "",
            chipRect: nil, buttonWidth: 0, eventCount: 0,
            isOverridden: false, hasSelectedCalendars: true
        )
    }
}

/// The harness window: titled, unlike the chromeless `DropdownInspectorWindow`.
final class DebugHarnessWindow: NSWindow {
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func close() {
        let handler = onClose
        onClose = nil
        handler?()
        super.close()
    }

    /// Whether `url` is the harness deep link (`punctual://debug-harness`).
    static func matches(_ url: URL) -> Bool {
        url.scheme == "punctual" && url.host == "debug-harness"
    }
}
#endif
