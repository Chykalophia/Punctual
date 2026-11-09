//
//  TimeFormatDefaultMigrationTests.swift
//  PunctualTests
//
//  Tests the migration that keeps existing installs on 24-hour time while new installs default to 12-hour.
//

import XCTest

@testable import Punctual

final class TimeFormatDefaultMigrationTests: XCTestCase {
    func testUpgraderWithNoExplicitChoiceIsPinnedTo24Hour() {
        XCTAssertTrue(
            TimeFormatDefaultMigration.shouldPinToMilitary(
                onboardingCompleted: true, hasStoredTimeFormat: false
            )
        )
    }

    func testUpgraderWithExplicitChoiceIsNotPinned() {
        XCTAssertFalse(
            TimeFormatDefaultMigration.shouldPinToMilitary(
                onboardingCompleted: true, hasStoredTimeFormat: true
            )
        )
    }

    func testNewInstallIsNotPinned() {
        XCTAssertFalse(
            TimeFormatDefaultMigration.shouldPinToMilitary(
                onboardingCompleted: false, hasStoredTimeFormat: false
            )
        )
    }

    func testNewInstallWithStoredValueIsNotPinned() {
        XCTAssertFalse(
            TimeFormatDefaultMigration.shouldPinToMilitary(
                onboardingCompleted: false, hasStoredTimeFormat: true
            )
        )
    }
}
