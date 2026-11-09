//
//  AgendaSectionVisibilityTests.swift
//  PunctualLogicTests
//
//  Tests for which agenda day sections are drawn when empty days are hidden.
//

import XCTest

@testable import PunctualLogic

final class AgendaSectionVisibilityTests: XCTestCase {
    private func shows(
        count: Int,
        included: Bool = true,
        hidesEmpty: Bool,
        anchor: Bool = false
    ) -> Bool {
        AgendaSectionVisibilityPolicy.showsSection(
            eventCount: count,
            isIncludedByPeriod: included,
            hidesEmptyDays: hidesEmpty,
            isAnchorDay: anchor
        )
    }

    // MARK: - The setting off: nothing changes

    func testEmptyLookAheadDayStillShowsWhenTheSettingIsOff() {
        XCTAssertTrue(shows(count: 0, hidesEmpty: false))
    }

    func testPopulatedDayShowsEitherWay() {
        XCTAssertTrue(shows(count: 3, hidesEmpty: false))
        XCTAssertTrue(shows(count: 3, hidesEmpty: true))
    }

    // MARK: - The setting on

    func testEmptyLookAheadDayIsHiddenWhenTheSettingIsOn() {
        XCTAssertFalse(shows(count: 0, hidesEmpty: true))
    }

    func testOneEventIsEnoughToKeepTheSection() {
        XCTAssertTrue(shows(count: 1, hidesEmpty: true))
    }

    // MARK: - Today is never hidden

    func testTodayShowsEvenWhenEmptyAndHidingIsOn() {
        XCTAssertTrue(shows(count: 0, hidesEmpty: true, anchor: true))
    }

    func testTodayShowsEmptyRegardlessOfTheSetting() {
        XCTAssertTrue(shows(count: 0, hidesEmpty: false, anchor: true))
    }

    // MARK: - The period wins over everything

    func testDayOutsideTheLookAheadPeriodIsNeverShown() {
        XCTAssertFalse(shows(count: 5, included: false, hidesEmpty: false))
        XCTAssertFalse(shows(count: 5, included: false, hidesEmpty: true))
        XCTAssertFalse(shows(count: 0, included: false, hidesEmpty: true))
    }

    func testAnchorDayStillObeysThePeriod() {
        XCTAssertFalse(shows(count: 0, included: false, hidesEmpty: true, anchor: true))
    }
}
