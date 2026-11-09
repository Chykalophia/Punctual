//
//  MoreActionsMenuTests.swift
//  PunctualTests
//
//  Pins the item sequence, separators included, of the dropdown's "More actions" flyout
//  built by `DropdownPanelView.makeMoreActionsMenu()`.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import XCTest

@testable import Punctual

@MainActor
final class MoreActionsMenuTests: BaseTestCase {
    /// Fixed so "dismiss NEXT" vs "dismiss CURRENT" never depends on wall clock.
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeMenu(
        nextEvent: MBEvent? = nil,
        dismissed: [ProcessedEvent] = [],
        titleFormat: EventTitleFormat = .dot
    ) -> NSMenu {
        var settings = AppSettings.empty
        settings.events.dismissedEvents = dismissed
        settings.statusBar.eventTitleFormat = titleFormat

        var state = StatusBarMenuState()
        state.settings = settings
        state.nextEvent = nextEvent

        return DropdownPanelView(
            state: state,
            handlers: DropdownPanelHandlers(),
            now: now
        ).makeMoreActionsMenu()
    }

    /// Separators render as "---" so their placement is pinned too.
    private func titles(of menu: NSMenu) -> [String] {
        menu.items.map { $0.isSeparatorItem ? "---" : $0.title }
    }

    private func futureEvent() -> MBEvent {
        makeFakeEvent(
            id: "next",
            start: now.addingTimeInterval(600),
            end: now.addingTimeInterval(3600),
            withLink: true
        )
    }

    private func dismissal() -> ProcessedEvent {
        ProcessedEvent(id: "dismissed", eventEndDate: now.addingTimeInterval(3600))
    }

    /// Everything that is always present, in order.
    private var alwaysOn: [String] {
        [
            "status_bar_section_join_from_clipboard".loco(),
            "---",
            "status_bar_quick_action_open_calendar".loco(),
            "status_bar_quick_action_camera_check".loco(),
            "status_bar_quick_action_world_clock".loco(),
            "---",
            "status_bar_section_refresh_sources".loco()
        ]
    }

    // MARK: - The four combinations of the leading, conditional group

    func testNoNextMeetingAndNoDismissalsOmitsTheLeadingGroupEntirely() {
        XCTAssertEqual(titles(of: makeMenu()), alwaysOn)
    }

    func testNextMeetingAddsDismissFollowedByItsSeparator() {
        let menu = makeMenu(nextEvent: futureEvent())
        XCTAssertEqual(
            titles(of: menu),
            ["status_bar_menu_dismiss_next_meeting".loco(), "---"] + alwaysOn
        )
    }

    func testDismissalsAloneAddUndismissFollowedByItsSeparator() {
        let menu = makeMenu(dismissed: [dismissal()])
        XCTAssertEqual(
            titles(of: menu),
            ["status_bar_menu_remove_all_dismissals".loco(), "---"] + alwaysOn
        )
    }

    func testNextMeetingAndDismissalsAddBothWithOneSeparator() {
        let menu = makeMenu(nextEvent: futureEvent(), dismissed: [dismissal()])
        XCTAssertEqual(
            titles(of: menu),
            [
                "status_bar_menu_dismiss_next_meeting".loco(),
                "status_bar_menu_remove_all_dismissals".loco(),
                "---"
            ] + alwaysOn
        )
    }

    // MARK: - Dismiss row wording

    func testDismissRowSaysCurrentOnceTheMeetingHasStarted() {
        let started = makeFakeEvent(
            id: "running",
            start: now.addingTimeInterval(-300),
            end: now.addingTimeInterval(1800),
            withLink: true
        )
        XCTAssertEqual(
            titles(of: makeMenu(nextEvent: started)).first,
            "status_bar_menu_dismiss_curent_meeting".loco()
        )
    }

    // MARK: - Meeting-title visibility gating

    func testTitleVisibilityRowIsAbsentWhenTheMenuBarShowsNoTitle() {
        for format in [EventTitleFormat.dot, .none] {
            let titles = titles(of: makeMenu(titleFormat: format))
            XCTAssertEqual(titles, alwaysOn, "unexpected extra row for \(format)")
        }
    }

    func testTitleVisibilityRowOffersToHideWhenTitlesAreShown() {
        let titles = titles(of: makeMenu(titleFormat: .show))
        XCTAssertTrue(
            titles.contains("status_bar_hide_meeting_names".loco()),
            "expected a hide-names row, got \(titles)"
        )
    }

    func testTitleVisibilityRowOffersToShowWhenTitlesAreGeneric() {
        let titles = titles(of: makeMenu(titleFormat: .generic))
        XCTAssertTrue(
            titles.contains("status_bar_show_meeting_names".loco()),
            "expected a show-names row, got \(titles)"
        )
    }

    func testTitleVisibilityRowSitsDirectlyBelowTheClipboardRow() {
        let titles = titles(of: makeMenu(titleFormat: .show))
        guard let clipboard = titles.firstIndex(of: "status_bar_section_join_from_clipboard".loco()) else {
            return XCTFail("clipboard row missing from \(titles)")
        }
        XCTAssertEqual(titles[clipboard + 1], "status_bar_hide_meeting_names".loco())
    }

    // MARK: - Enablement

    func testEveryActionableItemIsEnabledAndCarriesAnAction() {
        let menu = makeMenu(
            nextEvent: futureEvent(),
            dismissed: [dismissal()],
            titleFormat: .show
        )
        XCTAssertFalse(menu.autoenablesItems)
        for item in menu.items where !item.isSeparatorItem {
            XCTAssertTrue(item.isEnabled, "\(item.title) is disabled")
            XCTAssertNotNil(item.action, "\(item.title) has no action")
            XCTAssertNotNil(item.target, "\(item.title) has no target")
        }
    }

    func testNoDuplicateRows() {
        let titles = titles(of: makeMenu(
            nextEvent: futureEvent(),
            dismissed: [dismissal()],
            titleFormat: .show
        )).filter { $0 != "---" }
        XCTAssertEqual(Set(titles).count, titles.count, "duplicate rows in \(titles)")
    }

    private struct Scenario {
        var nextEvent: MBEvent?
        var dismissed: [ProcessedEvent] = []
        var titleFormat: EventTitleFormat = .dot
    }

    func testSeparatorsNeverStrandThemselves() {
        let scenarios = [
            Scenario(),
            Scenario(nextEvent: futureEvent()),
            Scenario(dismissed: [dismissal()]),
            Scenario(nextEvent: futureEvent(), dismissed: [dismissal()], titleFormat: .show)
        ]
        for scenario in scenarios {
            let titles = titles(of: makeMenu(
                nextEvent: scenario.nextEvent,
                dismissed: scenario.dismissed,
                titleFormat: scenario.titleFormat
            ))
            XCTAssertNotEqual(titles.first, "---", "leading separator in \(titles)")
            XCTAssertNotEqual(titles.last, "---", "trailing separator in \(titles)")
            for (index, title) in titles.enumerated() where title == "---" && index > 0 {
                XCTAssertNotEqual(titles[index - 1], "---", "double separator in \(titles)")
            }
        }
    }
}
