//
//  LocationAutocompletePolicyTests.swift
//  PunctualLogicTests
//
//  Tests for the location-autocomplete gate: nothing is sent unless it is enabled.
//

import XCTest

@testable import PunctualLogic

final class LocationAutocompletePolicyTests: XCTestCase {
    // MARK: - The feature is off

    func testNothingIsSentWhenDisabled() {
        // Length, content and whitespace are irrelevant while the feature is off.
        for text in ["", "a", "abc", "Chicago", "   spaced out   ", String(repeating: "x", count: 500)] {
            XCTAssertFalse(
                LocationAutocompletePolicy.shouldQuery(text, isEnabled: false),
                "disabled must never query, but did for \(text.prefix(20))"
            )
        }
    }

    func testDisabledAlsoSuppressesStaleResults() {
        XCTAssertFalse(
            LocationAutocompletePolicy.shouldPresentResults(
                for: "Chicago", isEnabled: false, resultCount: 5
            )
        )
    }

    // MARK: - The feature is on

    func testShortQueriesAreNotSent() {
        XCTAssertFalse(LocationAutocompletePolicy.shouldQuery("", isEnabled: true))
        XCTAssertFalse(LocationAutocompletePolicy.shouldQuery("a", isEnabled: true))
        XCTAssertFalse(LocationAutocompletePolicy.shouldQuery("ab", isEnabled: true))
    }

    func testTheThresholdIsInclusive() {
        XCTAssertTrue(LocationAutocompletePolicy.shouldQuery("abc", isEnabled: true))
    }

    func testLongerQueriesAreSent() {
        XCTAssertTrue(LocationAutocompletePolicy.shouldQuery("Chicago", isEnabled: true))
    }

    func testWhitespaceDoesNotCountTowardTheThreshold() {
        // "  a  " is one real character once trimmed.
        XCTAssertFalse(LocationAutocompletePolicy.shouldQuery("  a  ", isEnabled: true))
        XCTAssertTrue(LocationAutocompletePolicy.shouldQuery("  abc  ", isEnabled: true))
    }

    func testAWhitespaceOnlyQueryIsNeverSent() {
        XCTAssertFalse(LocationAutocompletePolicy.shouldQuery("      ", isEnabled: true))
        XCTAssertFalse(LocationAutocompletePolicy.shouldQuery("\n\t ", isEnabled: true))
    }

    // MARK: - Presenting results

    func testResultsNeedBothAQueryWorthSendingAndSomethingToShow() {
        XCTAssertTrue(
            LocationAutocompletePolicy.shouldPresentResults(
                for: "Chicago", isEnabled: true, resultCount: 3
            )
        )
        XCTAssertFalse(
            LocationAutocompletePolicy.shouldPresentResults(
                for: "Chicago", isEnabled: true, resultCount: 0
            )
        )
    }

    func testDeletingBackBelowTheThresholdHidesStaleResults() {
        XCTAssertFalse(
            LocationAutocompletePolicy.shouldPresentResults(
                for: "ab", isEnabled: true, resultCount: 5
            )
        )
    }

    // MARK: - Configurable threshold

    func testAnExplicitThresholdIsHonoured() {
        XCTAssertTrue(
            LocationAutocompletePolicy.shouldQuery("ab", isEnabled: true, minimumLength: 2)
        )
        XCTAssertFalse(
            LocationAutocompletePolicy.shouldQuery("abcd", isEnabled: true, minimumLength: 5)
        )
    }

    func testAnExplicitThresholdStillCannotBypassTheOffSwitch() {
        // A zero threshold must not become a way to query while disabled.
        XCTAssertFalse(
            LocationAutocompletePolicy.shouldQuery("", isEnabled: false, minimumLength: 0)
        )
    }
}
