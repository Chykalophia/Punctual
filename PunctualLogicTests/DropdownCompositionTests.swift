//
//  DropdownCompositionTests.swift
//  PunctualLogicTests
//
//  Tests for the composable dropdown module policy.
//

import XCTest

@testable import PunctualLogic

final class DropdownCompositionTests: XCTestCase {
    private let allEnabled = Set(DropdownModule.allCases.map(\.rawValue))
    private var standardOrderRaw: [String] {
        DropdownComposition.standard.modules.map(\.rawValue)
    }

    func testStandardIsTheClassicOrder() {
        XCTAssertEqual(
            DropdownComposition.standard.modules,
            [.greeting, .timeline, .meeting, .calendar, .agenda, .join, .bookmarks]
        )
    }

    func testDefaultOrderResolvesToStandard() {
        let resolved = DropdownCompositionPolicy.resolve(
            order: standardOrderRaw,
            enabled: allEnabled
        )
        XCTAssertEqual(resolved, DropdownComposition.standard.modules)
    }

    func testEmptyOrderYieldsAllStandardModules() {
        let resolved = DropdownCompositionPolicy.resolve(order: [], enabled: allEnabled)
        XCTAssertEqual(resolved, DropdownComposition.standard.modules)
    }

    func testUnknownRawStringsAreDropped() {
        let resolved = DropdownCompositionPolicy.resolve(
            order: ["greeting", "made_up_module", "timeline", ""],
            enabled: allEnabled
        )
        // Unknowns vanish, the given order is kept (greeting then timeline), then missing
        // standard modules append. A retired module such as "upNext" is dropped the same way.
        XCTAssertEqual(
            resolved,
            [.greeting, .timeline, .meeting, .calendar, .agenda, .join, .bookmarks]
        )
    }

    func testMissingModuleAppendsInStandardPosition() {
        // `meeting` is absent from the stored order; it should reappear at its
        // standard position relative to the other appended modules.
        let resolved = DropdownCompositionPolicy.resolve(
            order: ["greeting", "timeline", "agenda", "join", "bookmarks"],
            enabled: allEnabled
        )
        XCTAssertEqual(
            resolved,
            [.greeting, .timeline, .agenda, .join, .bookmarks, .meeting, .calendar]
        )
    }

    func testDuplicatesAreDeduplicatedFirstWins() {
        let resolved = DropdownCompositionPolicy.resolve(
            order: ["bookmarks", "greeting", "bookmarks", "greeting"],
            enabled: allEnabled
        )
        // First occurrence of each wins; the rest append in standard order.
        XCTAssertEqual(
            resolved,
            [.bookmarks, .greeting, .timeline, .meeting, .calendar, .agenda, .join]
        )
    }

    func testEnabledFilterRemovesDisabledModules() {
        let resolved = DropdownCompositionPolicy.resolve(
            order: standardOrderRaw,
            enabled: ["greeting", "meeting", "join"]
        )
        XCTAssertEqual(resolved, [.greeting, .meeting, .join])
    }

    func testEnabledFilterKeepsCustomOrder() {
        let resolved = DropdownCompositionPolicy.resolve(
            order: ["join", "meeting", "greeting", "timeline", "agenda", "bookmarks"],
            enabled: ["join", "greeting"]
        )
        XCTAssertEqual(resolved, [.join, .greeting])
    }

    func testEmptyEnabledYieldsNothing() {
        let resolved = DropdownCompositionPolicy.resolve(
            order: standardOrderRaw,
            enabled: []
        )
        XCTAssertTrue(resolved.isEmpty)
    }

    // MARK: - enabledRawValues (shared by the controller + Display-tab preview)

    func testEnabledRawValuesReflectsEachToggle() {
        XCTAssertEqual(
            DropdownCompositionPolicy.enabledRawValues(
                greeting: true, timeline: false, meeting: true,
                agenda: false, join: true, bookmarks: false, calendar: false
            ),
            ["greeting", "meeting", "join"]
        )
    }

    func testEnabledRawValuesAllOnMatchesEveryModule() {
        XCTAssertEqual(
            DropdownCompositionPolicy.enabledRawValues(
                greeting: true, timeline: true, meeting: true,
                agenda: true, join: true, bookmarks: true, calendar: true
            ),
            allEnabled
        )
    }

    func testEnabledRawValuesAllOffIsEmpty() {
        XCTAssertTrue(
            DropdownCompositionPolicy.enabledRawValues(
                greeting: false, timeline: false, meeting: false,
                agenda: false, join: false, bookmarks: false, calendar: false
            ).isEmpty
        )
    }

    func testEnabledRawValuesFeedsResolveDeterministically() {
        let enabled = DropdownCompositionPolicy.enabledRawValues(
            greeting: true, timeline: false, meeting: true,
            agenda: true, join: false, bookmarks: false, calendar: false
        )
        let resolved = DropdownCompositionPolicy.resolve(order: standardOrderRaw, enabled: enabled)
        XCTAssertEqual(resolved, [.greeting, .meeting, .agenda])
    }

    // MARK: - Separators

    func test_contentModulesGetNoSeparators() {
        XCTAssertEqual(
            DropdownSeparatorPolicy.separatorIndices(
                for: [.greeting, .timeline, .meeting, .calendar, .agenda]
            ),
            []
        )
    }

    func test_separatorSitsAboveTheActionList() {
        XCTAssertEqual(
            DropdownSeparatorPolicy.separatorIndices(
                for: [.greeting, .agenda, .join]
            ),
            [2]
        )
    }

    func test_adjacentActionListsShareASingleSeparator() {
        XCTAssertEqual(
            DropdownSeparatorPolicy.separatorIndices(
                for: [.agenda, .join, .bookmarks]
            ),
            [1]
        )
    }

    func test_neverSeparatesTheFirstModule() {
        XCTAssertEqual(DropdownSeparatorPolicy.separatorIndices(for: [.join, .agenda]), [])
        XCTAssertEqual(DropdownSeparatorPolicy.separatorIndices(for: []), [])
    }

    func test_actionListsSplitByContentGetTheirOwnSeparators() {
        XCTAssertEqual(
            DropdownSeparatorPolicy.separatorIndices(
                for: [.agenda, .join, .timeline, .bookmarks]
            ),
            [1, 3]
        )
    }

    func test_everyModuleIsClassifiedAsContentOrAction() {
        let actions = DropdownModule.allCases.filter(\.isActionList)
        XCTAssertEqual(Set(actions), [.join, .bookmarks])
    }
}
