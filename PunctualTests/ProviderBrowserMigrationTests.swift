//
//  ProviderBrowserMigrationTests.swift
//  PunctualTests
//
//  Tests for `MeetingOpenPreferencesMigration`, which folds the legacy per-provider browser keys
//  into the `providerBrowsers` map.
//

import Defaults
import XCTest

@testable import Punctual

@MainActor
final class ProviderBrowserMigrationTests: BaseTestCase {
    private let defaultBrowser = Browser(name: "Default Browser", path: "")
    private let zoomApp = Browser(name: "Zoom", path: "")
    private let teamsApp = Browser(name: "Teams", path: "")
    private let chrome = Browser(name: "Google Chrome", path: "/Applications/Google Chrome.app")

    // MARK: - Pure migration logic

    func testMigrateReturnsEmptyMapWhenAllBrowsersAreSystemDefault() {
        let legacy: [(String, Browser)] = [
            ("Google Meet", defaultBrowser),
            ("Zoom", defaultBrowser)
        ]
        let result = MeetingOpenPreferencesMigration.migrate(
            legacyValues: legacy,
            systemDefault: defaultBrowser
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testMigrateIncludesOnlyNonDefaultEntries() {
        let legacy: [(String, Browser)] = [
            ("Google Meet", defaultBrowser),
            ("Zoom", zoomApp),
            ("Microsoft Teams", teamsApp)
        ]
        let result = MeetingOpenPreferencesMigration.migrate(
            legacyValues: legacy,
            systemDefault: defaultBrowser
        )
        XCTAssertNil(result["Google Meet"])
        XCTAssertEqual(result["Zoom"], zoomApp)
        XCTAssertEqual(result["Microsoft Teams"], teamsApp)
    }

    func testMigratePreservesCustomBrowserEntry() {
        let legacy: [(String, Browser)] = [
            ("Zoom", chrome)
        ]
        let result = MeetingOpenPreferencesMigration.migrate(
            legacyValues: legacy,
            systemDefault: defaultBrowser
        )
        XCTAssertEqual(result["Zoom"], chrome)
    }

    func testMigrateHandlesEmptyInput() {
        let result = MeetingOpenPreferencesMigration.migrate(
            legacyValues: [],
            systemDefault: defaultBrowser
        )
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Defaults-backed migration runner

    func testMigrateDefaultsIfNeeded_populatesMapFromLegacyKeys() {
        Defaults[.zoomBrowser] = zoomApp
        Defaults[.providerBrowsers] = [:]

        MeetingOpenPreferencesMigration.migrateDefaultsIfNeeded()

        XCTAssertEqual(Defaults[.providerBrowsers]["Zoom"], zoomApp)
    }

    func testMigrateDefaultsIfNeeded_skipsWhenAlreadyPopulated() {
        // Map already populated.
        let existingMap = ["Zoom": chrome]
        Defaults[.providerBrowsers] = existingMap
        Defaults[.zoomBrowser] = zoomApp

        MeetingOpenPreferencesMigration.migrateDefaultsIfNeeded()

        XCTAssertEqual(Defaults[.providerBrowsers]["Zoom"], chrome)
    }

    func testMigrateDefaultsIfNeeded_doesNotWriteWhenAllLegacyKeysAreDefault() {
        // All legacy keys at their default (systemDefaultBrowser).
        Defaults[.providerBrowsers] = [:]

        MeetingOpenPreferencesMigration.migrateDefaultsIfNeeded()

        XCTAssertTrue(Defaults[.providerBrowsers].isEmpty)
    }

    func testMigrateDefaultsIfNeeded_migratesAllSixProviders() {
        let meet = Browser(name: "MeetInOne", path: "")
        let slack = Browser(name: "Slack", path: "")
        let riverside = Browser(name: "Riverside", path: "")
        let jitsi = Browser(name: "Jitsi", path: "")
        Defaults[.meetBrowser] = meet
        Defaults[.zoomBrowser] = zoomApp
        Defaults[.teamsBrowser] = teamsApp
        Defaults[.jitsiBrowser] = jitsi
        Defaults[.slackBrowser] = slack
        Defaults[.riversideBrowser] = riverside
        Defaults[.providerBrowsers] = [:]

        MeetingOpenPreferencesMigration.migrateDefaultsIfNeeded()

        let prefs = Defaults[.providerBrowsers]
        XCTAssertEqual(prefs["Google Meet"], meet)
        XCTAssertEqual(prefs["Zoom"], zoomApp)
        XCTAssertEqual(prefs["Microsoft Teams"], teamsApp)
        XCTAssertEqual(prefs["Jitsi"], jitsi)
        XCTAssertEqual(prefs["Slack"], slack)
        XCTAssertEqual(prefs["Riverside"], riverside)
    }

    // MARK: - MeetingSettings snapshot includes providerBrowsers

    func testMeetingSettings_providerBrowsers_reflectsDefaults() {
        Defaults[.providerBrowsers] = ["Zoom": zoomApp]
        XCTAssertEqual(AppSettings.current.meetings.providerBrowsers["Zoom"], zoomApp)
    }
}
