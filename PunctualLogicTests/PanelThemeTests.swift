//
//  PanelThemeTests.swift
//  PunctualLogicTests
//
//  Tests for the panel theme: lenient decoding and system versus forced appearance.
//

import XCTest

@testable import PunctualLogic

final class PanelThemeTests: XCTestCase {
    // MARK: - Decoding

    func testKnownAppearancesDecode() {
        XCTAssertEqual(PanelThemePolicy.appearance(fromRaw: "light"), .light)
        XCTAssertEqual(PanelThemePolicy.appearance(fromRaw: "dark"), .dark)
        XCTAssertEqual(PanelThemePolicy.appearance(fromRaw: "system"), .system)
    }

    func testUnknownAppearanceFallsBackToSystem() {
        XCTAssertEqual(PanelThemePolicy.appearance(fromRaw: "solarized"), .system)
        XCTAssertEqual(PanelThemePolicy.appearance(fromRaw: ""), .system)
    }

    func testKnownAccentsDecode() {
        for accent in PanelAccent.allCases {
            XCTAssertEqual(PanelThemePolicy.accent(fromRaw: accent.rawValue), accent)
        }
    }

    func testUnknownAccentFallsBackToSystem() {
        XCTAssertEqual(PanelThemePolicy.accent(fromRaw: "chartreuse"), .system)
        XCTAssertEqual(PanelThemePolicy.accent(fromRaw: ""), .system)
    }

    func testDecodingIsCaseSensitive() {
        // Matching is case-sensitive on purpose: raw values are only ever written by the app.
        XCTAssertEqual(PanelThemePolicy.appearance(fromRaw: "Dark"), .system)
    }

    // MARK: - Forcing

    func testSystemDoesNotForceAnAppearance() {
        // nil, not light: a window with no explicit appearance keeps following the system.
        XCTAssertNil(PanelThemePolicy.forcedAppearance(.system))
    }

    func testExplicitAppearancesAreForced() {
        XCTAssertEqual(PanelThemePolicy.forcedAppearance(.light), .light)
        XCTAssertEqual(PanelThemePolicy.forcedAppearance(.dark), .dark)
    }

    // MARK: - Accent override

    func testSystemAccentDoesNotOverride() {
        XCTAssertFalse(PanelAccent.system.overridesSystem)
    }

    func testEveryOtherAccentOverrides() {
        for accent in PanelAccent.allCases where accent != .system {
            XCTAssertTrue(accent.overridesSystem, "\(accent) should override")
        }
    }

    // MARK: - Defaults

    func testTheDefaultOfBothAxesIsSystem() {
        XCTAssertEqual(PanelAppearance.allCases.first, .system)
        XCTAssertEqual(PanelAccent.allCases.first, .system)
    }
}
