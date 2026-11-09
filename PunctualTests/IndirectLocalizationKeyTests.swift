//
//  IndirectLocalizationKeyTests.swift
//  PunctualTests
//
//  Resolves every localization key reached through a property, which the string linters cannot
//  see, and fails if the bundle returns the key itself.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import XCTest

@testable import Punctual

final class IndirectLocalizationKeyTests: XCTestCase {
    /// A key resolves when the bundle returns something other than the key.
    private func assertResolves(
        _ key: String,
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(key.isEmpty, "\(label): empty key", file: file, line: line)
        let localized = key.loco()
        XCTAssertNotEqual(
            localized,
            key,
            "\(label): \"\(key)\" is not defined in en.lproj — it would render as the raw key",
            file: file, line: line
        )
        XCTAssertFalse(
            localized.trimmingCharacters(in: .whitespaces).isEmpty,
            "\(label): \"\(key)\" resolves to an empty string",
            file: file, line: line
        )
    }

    // MARK: - Preferences panes

    func testEveryPaneTitleAndPurposeResolves() {
        for tab in PreferencesTab.allCases {
            assertResolves(tab.titleKey, "PreferencesTab.\(tab).titleKey")
            assertResolves(tab.purposeKey, "PreferencesTab.\(tab).purposeKey")
        }
    }

    // MARK: - Calendar source presentation

    func testEveryCalendarSourceKeyResolves() {
        for provider in [EventStoreProvider.macOSEventKit, .googleCalendar] {
            let source = CalendarSourcePresentation.make(for: provider)
            assertResolves(source.titleKey, "CalendarSource(\(provider)).titleKey")
            assertResolves(source.descriptionKey, "CalendarSource(\(provider)).descriptionKey")
            assertResolves(source.dataSourceKey, "CalendarSource(\(provider)).dataSourceKey")
            assertResolves(source.accountScopeKey, "CalendarSource(\(provider)).accountScopeKey")
            assertResolves(
                source.authorizationDescriptionKey,
                "CalendarSource(\(provider)).authorizationDescriptionKey"
            )
        }
    }

    // MARK: - Calendar sync status

    /// Driven through `make(from:)` rather than a hardcoded list, so a new state cannot ship without its strings.
    func testEverySyncStatusKeyResolves() {
        for presentation in Self.allCalendarPresentations() {
            assertResolves(
                presentation.statusTextKey,
                "PreferencesCalendarPresentation(\(presentation.connectionState)).statusTextKey"
            )
            assertResolves(
                presentation.emptyStateTextKey,
                "PreferencesCalendarPresentation(\(presentation.connectionState)).emptyStateTextKey"
            )
            assertResolves(
                presentation.providerTitleKey,
                "PreferencesCalendarPresentation(\(presentation.connectionState)).providerTitleKey"
            )
            assertResolves(
                presentation.providerDataSourceKey,
                "PreferencesCalendarPresentation(\(presentation.connectionState)).providerDataSourceKey"
            )
            assertResolves(
                presentation.providerAccountScopeKey,
                "PreferencesCalendarPresentation(\(presentation.connectionState)).providerAccountScopeKey"
            )
        }
    }

    /// Every connection state `PreferencesCalendarPresentation.make` can reach,
    /// built by driving the inputs that select each branch.
    private static func allCalendarPresentations() -> [PreferencesCalendarPresentation] {
        var results: [PreferencesCalendarPresentation] = []

        // .initializing — never refreshed, no error.
        results.append(.make(from: AppState()))

        // .authRequired
        var authState = AppState()
        authState.providerHealth.authRequired = true
        results.append(.make(from: authState))

        // .permissionRequired — errored and never succeeded, on EventKit.
        var permissionState = AppState()
        permissionState.activeProvider = .macOSEventKit
        permissionState.providerHealth.lastErrorDescription = "denied"
        results.append(.make(from: permissionState))

        // .stale
        var staleState = AppState()
        staleState.providerHealth.isStale = true
        results.append(.make(from: staleState))

        // .error — errored but has succeeded before.
        var errorState = AppState()
        errorState.providerHealth.lastErrorDescription = "boom"
        errorState.providerHealth.lastSuccessfulRefresh = Date()
        results.append(.make(from: errorState))

        // .connected, but exposing zero calendars (the "no accounts" branch).
        var emptyState = AppState()
        emptyState.providerHealth.lastSuccessfulRefresh = Date()
        results.append(.make(from: emptyState))

        // .notDetermined authorization — surfaces "Grant Calendar Access".
        var notDeterminedState = AppState()
        notDeterminedState.activeProvider = .macOSEventKit
        results.append(.make(from: notDeterminedState, authorizationStatus: .notDetermined))

        return results
    }
}
