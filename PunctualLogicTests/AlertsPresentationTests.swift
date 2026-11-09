//
//  AlertsPresentationTests.swift
//  PunctualLogicTests
//
//  Tests for the Alerts pane's notification permission-state mapping.
//

import XCTest

@testable import PunctualLogic

final class AlertsPresentationTests: XCTestCase {
    /// The English catalog, parsed from the repo because `swift test` has no host bundle.
    /// Those directory names contain real trailing spaces.
    private static let englishCatalog: [String: String] = {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PunctualLogicTests
            .deletingLastPathComponent()  // repo root
        let strings = repoRoot
            .appendingPathComponent("Punctual")
            .appendingPathComponent("Resources ")
            .appendingPathComponent("Localization ")
            .appendingPathComponent("en.lproj")
            .appendingPathComponent("Localizable.strings")
        return NSDictionary(contentsOf: strings) as? [String: String] ?? [:]
    }()

    // MARK: - Resolution

    func testDeniedMeansNothingReachesYou() {
        XCTAssertEqual(
            NotificationDeliveryPolicy.resolve(authorization: .denied, staysOnscreen: true),
            .blocked
        )
        // The alert style is irrelevant once macOS is refusing to deliver.
        XCTAssertEqual(
            NotificationDeliveryPolicy.resolve(authorization: .denied, staysOnscreen: false),
            .blocked
        )
    }

    func testNotDeterminedIsTreatedAsBlocked() {
        XCTAssertEqual(
            NotificationDeliveryPolicy.resolve(authorization: .notDetermined, staysOnscreen: true),
            .blocked
        )
    }

    func testAllowedSplitsOnWhetherTheyStayOnscreen() {
        XCTAssertEqual(
            NotificationDeliveryPolicy.resolve(authorization: .allowed, staysOnscreen: true),
            .persistent
        )
        XCTAssertEqual(
            NotificationDeliveryPolicy.resolve(authorization: .allowed, staysOnscreen: false),
            .disappearing
        )
    }

    // MARK: - What the pane shows

    func testTheCalmStateSaysNothingAndOffersNoButton() {
        XCTAssertNil(NotificationDelivery.persistent.messageKey)
        XCTAssertFalse(NotificationDelivery.persistent.offersSettingsButton)
        XCTAssertFalse(NotificationDelivery.persistent.isProblem)
    }

    func testEveryOtherStateOffersTheButtonRatherThanInstructions() {
        for delivery in [NotificationDelivery.blocked, .disappearing] {
            XCTAssertNotNil(delivery.messageKey, "\(delivery.rawValue) has nothing to say")
            XCTAssertTrue(
                delivery.offersSettingsButton,
                "\(delivery.rawValue) must offer a real button, not prose telling the user to go find System Settings"
            )
        }
    }

    func testOnlyBlockedReadsAsAProblem() {
        XCTAssertTrue(NotificationDelivery.blocked.isProblem)
        // Banners still arrive, so this is advice rather than a failure.
        XCTAssertFalse(NotificationDelivery.disappearing.isProblem)
    }

    func testEveryMessageKeyIsDefinedInEnglish() {
        XCTAssertFalse(Self.englishCatalog.isEmpty, "en.lproj failed to parse")
        for delivery in NotificationDelivery.allCases {
            guard let key = delivery.messageKey else { continue }
            XCTAssertNotNil(
                Self.englishCatalog[key],
                "\(delivery.rawValue): '\(key)' is not defined in en.lproj"
            )
        }
        XCTAssertNotNil(Self.englishCatalog[NotificationDelivery.settingsButtonKey])
    }
}
