//
//  CalendarSourceSelectionTests.swift
//  PunctualLogicTests
//
//  Tests for multi-source calendar connection.
//

import XCTest

@testable import PunctualLogic

final class CalendarSourceSelectionTests: XCTestCase {
    // MARK: - The non-empty invariant

    func test_emptySelectionFallsBackToMacOSCalendar() {
        XCTAssertEqual(CalendarSourceSelection(enabled: []).enabled, [.macOSEventKit])
    }

    func test_disablingTheLastSourceIsRefused() {
        let selection = CalendarSourceSelection(enabled: [.googleCalendar])
        XCTAssertFalse(selection.canDisable(.googleCalendar))
        XCTAssertEqual(selection.disabling(.googleCalendar).enabled, [.googleCalendar])
    }

    func test_disablingIsAllowedWhileASecondSourceRemains() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit, .googleCalendar])
        XCTAssertTrue(selection.canDisable(.macOSEventKit))
        XCTAssertEqual(selection.disabling(.macOSEventKit).enabled, [.googleCalendar])
    }

    // MARK: - Selected calendars across sources

    func test_selectedCalendarIDs_unionsEveryConnectedSource_inDisplayOrder() {
        let selection = CalendarSourceSelection(enabled: [.googleCalendar, .macOSEventKit])
        let ids = selection.selectedCalendarIDs(byProviderKey: [
            CalendarSourceKind.googleCalendar.rawValue: ["g1"],
            CalendarSourceKind.macOSEventKit.rawValue: ["m1", "m2"]
        ])
        XCTAssertEqual(ids, ["m1", "m2", "g1"])
    }

    func test_selectedCalendarIDs_primaryEmpty_otherSourceTicked_isNotEmpty() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit, .googleCalendar])
        let ids = selection.selectedCalendarIDs(byProviderKey: [
            CalendarSourceKind.macOSEventKit.rawValue: [],
            CalendarSourceKind.googleCalendar.rawValue: ["g1"]
        ])
        XCTAssertEqual(ids, ["g1"])
    }

    func test_selectedCalendarIDs_ignoresDisconnectedSourcesAndMissingKeys() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit])
        XCTAssertEqual(
            selection.selectedCalendarIDs(byProviderKey: [
                CalendarSourceKind.googleCalendar.rawValue: ["g1"]
            ]),
            []
        )
    }

    // MARK: - Normalization

    func test_orderIsCanonicalRegardlessOfInputOrder() {
        let selection = CalendarSourceSelection(enabled: [.googleCalendar, .macOSEventKit])
        XCTAssertEqual(selection.enabled, [.macOSEventKit, .googleCalendar])
    }

    func test_duplicatesAreCollapsed() {
        let selection = CalendarSourceSelection(enabled: [.googleCalendar, .googleCalendar])
        XCTAssertEqual(selection.enabled, [.googleCalendar])
    }

    // MARK: - Toggling

    func test_enablingIsIdempotent() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit])
        XCTAssertEqual(selection.enabling(.macOSEventKit), selection)
    }

    func test_bothSourcesCanBeEnabledAtOnce() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit])
            .enabling(.googleCalendar)
        XCTAssertEqual(selection.enabled, [.macOSEventKit, .googleCalendar])
    }

    func test_settingDrivesBothDirections() {
        var selection = CalendarSourceSelection(enabled: [.macOSEventKit])
        selection = selection.setting(.googleCalendar, enabled: true)
        XCTAssertTrue(selection.isEnabled(.googleCalendar))
        selection = selection.setting(.googleCalendar, enabled: false)
        XCTAssertFalse(selection.isEnabled(.googleCalendar))
    }

    // MARK: - Availability filtering

    func test_unavailableSourcesAreDroppedOnRead() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit, .googleCalendar])
            .availableOnly { $0 != .googleCalendar }
        XCTAssertEqual(selection.enabled, [.macOSEventKit])
    }

    func test_filteringEverythingAwayRestoresMacOSCalendar() {
        // A build with no Google credentials, on an install that selected Google only.
        let selection = CalendarSourceSelection(enabled: [.googleCalendar])
            .availableOnly { _ in false }
        XCTAssertEqual(selection.enabled, [.macOSEventKit])
    }

    func test_filteringIsNotPersistedBackIntoTheSelection() {
        // The stored selection keeps Google so credentials added later restore it.
        let stored = CalendarSourceSelection(enabled: [.macOSEventKit, .googleCalendar])
        _ = stored.availableOnly { $0 != .googleCalendar }
        XCTAssertTrue(stored.isEnabled(.googleCalendar))
    }

    // MARK: - Migration off the single-provider key

    func test_migrationKeepsExactlyTheProviderInUse() {
        XCTAssertEqual(
            CalendarSourceSelection.migrating(fromSingleProvider: .googleCalendar).enabled,
            [.googleCalendar]
        )
        XCTAssertEqual(
            CalendarSourceSelection.migrating(fromSingleProvider: .macOSEventKit).enabled,
            [.macOSEventKit]
        )
    }

    // MARK: - Writes

    func test_writeSourceIsEventKitWhenConnected() {
        let selection = CalendarSourceSelection(enabled: [.macOSEventKit, .googleCalendar])
        XCTAssertEqual(selection.writeSource, .macOSEventKit)
    }

    func test_googleOnlyHasNoWriteSource() {
        // The Google provider is read-only, so a Google-only install cannot write.
        let selection = CalendarSourceSelection(enabled: [.googleCalendar])
        XCTAssertNil(selection.writeSource)
    }

    // MARK: - Deduplication precedence

    func test_googleOutranksEventKitForSurvivingCopy() {
        XCTAssertLessThan(
            CalendarSourceKind.googleCalendar.deduplicationPriority,
            CalendarSourceKind.macOSEventKit.deduplicationPriority
        )
    }

    func test_displayOrderAndDedupPrecedenceAreAllowedToDisagree() {
        // Listed first, yet loses the duplicate tie-break; the two orders differ on purpose.
        XCTAssertEqual(CalendarSourceKind.displayOrder.first, .macOSEventKit)
        XCTAssertEqual(
            CalendarSourceKind.allCases.min(by: { $0.deduplicationPriority < $1.deduplicationPriority }),
            .googleCalendar
        )
    }
}
