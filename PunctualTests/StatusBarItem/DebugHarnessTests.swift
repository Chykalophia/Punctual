//
//  DebugHarnessTests.swift
//  PunctualTests
//
//  Asserts each DEBUG harness scenario puts the app in the state it advertises; `nolink` must
//  stay a negative case with no detectable meeting link.
//

#if DEBUG
import Defaults
import XCTest

@testable import Punctual

@MainActor
final class DebugHarnessTests: BaseTestCase {
    private func scenario(_ id: String) -> DebugScenario {
        guard let found = DebugScenario.all.first(where: { $0.id == id }) else {
            fatalError("no debug scenario '\(id)'")
        }
        return found
    }

    private func makeController() -> StatusBarItemController {
        // With no calendar selected the menu bar is icon-only, whatever the events.
        Defaults[.enabledCalendarSources] = [.macOSEventKit]
        Defaults[.selectedCalendarIDsByProvider] = [
            EventStoreProvider.macOSEventKit.rawValue: ["debug-harness"]
        ]
        Defaults[.menuBarShowJoinAction] = true
        Defaults[.menuBarJoinActionLeadMinutes] = 2
        Defaults[.menuBarTokens] = [
            MenuBarTokenKind.icon.rawValue,
            MenuBarTokenKind.title.rawValue,
            MenuBarTokenKind.countdown.rawValue
        ]
        Defaults[.menuBarTimeFormatMigrated] = true
        return StatusBarItemController()
    }

    private func apply(_ id: String, to controller: StatusBarItemController) {
        controller.debugOverrideEvents(scenario(id).build.map { $0(Date()) })
    }

    // MARK: - The fake data reaches the menu bar

    func testChipScenarioArmsTheJoinChip() {
        let controller = makeController()
        defer { controller.removeFromStatusBar() }

        apply("chip", to: controller)

        let summary = controller.debugRenderSummary()
        XCTAssertTrue(summary.isOverridden)
        XCTAssertEqual(summary.eventCount, 1)
        XCTAssertEqual(summary.actionLabel, "Join")
        XCTAssertNotNil(summary.chipRect, "the chip scenario exists to produce a click target")
        XCTAssertTrue(summary.firstLine.contains("Debug meeting"))
    }

    func testNoLinkScenarioProducesNoChip() {
        let controller = makeController()
        defer { controller.removeFromStatusBar() }

        apply("nolink", to: controller)

        let summary = controller.debugRenderSummary()
        XCTAssertEqual(summary.eventCount, 1)
        XCTAssertEqual(summary.actionLabel, "", "no link means nowhere to join")
        XCTAssertNil(summary.chipRect, "a click here must still open the dropdown")
    }

    func testFarScenarioIsOutsideTheChipWindow() {
        let controller = makeController()
        defer { controller.removeFromStatusBar() }

        apply("far", to: controller)

        XCTAssertEqual(controller.debugRenderSummary().actionLabel, "")
    }

    func testRunningScenarioKeepsTheChipUp() {
        let controller = makeController()
        defer { controller.removeFromStatusBar() }

        apply("running", to: controller)

        XCTAssertEqual(
            controller.debugRenderSummary().actionLabel,
            "Join",
            "joining a meeting already in progress is the common case"
        )
    }

    func testEmptyScenarioClearsTheTitle() {
        let controller = makeController()
        defer { controller.removeFromStatusBar() }

        apply("empty", to: controller)

        let summary = controller.debugRenderSummary()
        XCTAssertTrue(summary.isOverridden, "an empty list is a scenario, not a reset")
        XCTAssertEqual(summary.eventCount, 0)
        XCTAssertEqual(summary.actionLabel, "")
    }

    func testRealCalendarScenarioDropsTheOverride() {
        let controller = makeController()
        defer { controller.removeFromStatusBar() }

        apply("chip", to: controller)
        XCTAssertTrue(controller.debugRenderSummary().isOverridden)

        apply("real", to: controller)
        XCTAssertFalse(
            controller.debugRenderSummary().isOverridden,
            "the harness must be able to hand the app back its real calendar"
        )
    }

    // MARK: - The scenarios themselves

    func testTheSyntheticMeetingLinkIsDetected() {
        let event = DebugScenario.meeting(now: Date(), startsIn: 90)
        XCTAssertNotNil(event.meetingLink, "the harness URL stopped being recognised as a meeting")
        XCTAssertEqual(event.meetingLink?.service, .meet)
    }

    func testTheNoLinkScenarioReallyHasNoLink() {
        let event = DebugScenario.meeting(now: Date(), startsIn: 90, hasLink: false)
        XCTAssertNil(event.meetingLink)
    }

    func testParticipationScenariosCarryTheirStatus() {
        for (id, expected) in [
            ("declined", MBEventAttendeeStatus.declined),
            ("pending", .pending),
            ("tentative", .tentative)
        ] {
            let events = scenario(id).build?(Date()) ?? []
            XCTAssertEqual(events.first?.participationStatus, expected, "scenario '\(id)'")
        }
    }

    func testEveryScenarioHasAUniqueIDAndBuildsWithoutCrashing() {
        let ids = DebugScenario.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate scenario id")
        for scenario in DebugScenario.all where scenario.build != nil {
            XCTAssertNoThrow(scenario.build?(Date()))
        }
    }

    func testScenariosAreRebasedOnEachApplication() {
        let first = scenario("chip").build?(Date()).first?.startDate
        let later = Date().addingTimeInterval(600)
        let second = scenario("chip").build?(later).first?.startDate
        XCTAssertNotNil(first)
        XCTAssertNotNil(second)
        XCTAssertEqual(
            second?.timeIntervalSince(first ?? .distantPast) ?? 0,
            600,
            accuracy: 2,
            "the builder captured a date instead of taking one"
        )
    }
}
#endif
