//
//  SoftwareUpdateConfigurationTests.swift
//  Punctual
//
//  Pins the Sparkle configuration in the built app's Info.plist and the entitlement files.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import XCTest

@testable import Punctual

final class SoftwareUpdateConfigurationTests: XCTestCase {
    private func info(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    func testFeedIsTheLatestGitHubReleaseOverHTTPS() {
        XCTAssertEqual(
            info("SUFeedURL") as? String,
            "https://github.com/Chykalophia/Punctual/releases/latest/download/appcast.xml"
        )
    }

    func testPublicKeyIsAValidEd25519Key() throws {
        let base64 = try XCTUnwrap(info("SUPublicEDKey") as? String)
        let raw = try XCTUnwrap(Data(base64Encoded: base64), "SUPublicEDKey is not base64")
        XCTAssertEqual(raw.count, 32, "an Ed25519 public key is 32 bytes")
    }

    func testSandboxInstallerServiceIsEnabled() {
        XCTAssertEqual(info("SUEnableInstallerLauncherService") as? Bool, true)
    }

    /// Xcode expands `$(PRODUCT_BUNDLE_IDENTIFIER)` in the files it signs with; LocalSigning is
    /// signed by plain `codesign`, which does not, so it must spell the ids out.
    func testEveryEntitlementsFileAllowsSparklesInstaller() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // PunctualTests
            .deletingLastPathComponent()  // repo root
        let bundleID = try XCTUnwrap(Bundle.main.bundleIdentifier)
        let expanded: Set<String> = ["\(bundleID)-spks", "\(bundleID)-spki"]
        let files: [(path: String, signedByXcode: Bool)] = [
            ("Punctual/Punctual.entitlements", true),
            ("XCConfig/DeveloperID.entitlements", true),
            ("XCConfig/LocalSigning.entitlements", false)
        ]
        for file in files {
            let url = repoRoot.appendingPathComponent(file.path)
            let plist = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any], file.path)
            let names = plist["com.apple.security.temporary-exception.mach-lookup.global-name"] as? [String] ?? []
            let resolved = Set(names.map {
                file.signedByXcode ? $0.replacingOccurrences(of: "$(PRODUCT_BUNDLE_IDENTIFIER)", with: bundleID) : $0
            })
            XCTAssertEqual(resolved, expanded, "\(file.path) would not let Sparkle's installer be reached")
        }
    }

    func testFeedMustBeSignedAndUpdatesVerifiedBeforeExtraction() {
        XCTAssertEqual(info("SURequireSignedFeed") as? Bool, true)
        XCTAssertEqual(info("SUVerifyUpdateBeforeExtraction") as? Bool, true)
    }
}

/// A misspelled optional Objective-C delegate method compiles and is never called, so each
/// is pinned by the exact selector Sparkle sends.
@MainActor
final class SoftwareUpdaterDelegateTests: XCTestCase {
    func testEveryDelegateMethodAnswersSparklesExactSelector() {
        let selectors = [
            "updaterShouldPromptForPermissionToCheckForUpdates:",
            "updater:willScheduleUpdateCheckAfterDelay:",
            "supportsGentleScheduledUpdateReminders",
            "standardUserDriverShouldHandleShowingScheduledUpdate:andInImmediateFocus:",
            "standardUserDriverWillHandleShowingUpdate:forUpdate:state:",
            "standardUserDriverDidReceiveUserAttentionForUpdate:",
            "standardUserDriverWillFinishUpdateSession"
        ]
        for name in selectors {
            XCTAssertTrue(
                SoftwareUpdater.shared.responds(to: NSSelectorFromString(name)),
                "SoftwareUpdater does not answer \(name); Sparkle would never call it"
            )
        }
    }

    func testScheduledUpdateIsNeverPulledInFrontButIsNeverLost() {
        // In focus already: Sparkle's window is fine.
        XCTAssertTrue(UpdateReminderPolicy.sparkleShowsScheduledUpdate(immediateFocus: true, notificationsAuthorized: true))
        XCTAssertTrue(UpdateReminderPolicy.sparkleShowsScheduledUpdate(immediateFocus: true, notificationsAuthorized: false))
        // In the background with notifications: a notification, no window.
        XCTAssertFalse(UpdateReminderPolicy.sparkleShowsScheduledUpdate(immediateFocus: false, notificationsAuthorized: true))
        // In the background without notifications: Sparkle's non-activating window.
        XCTAssertTrue(UpdateReminderPolicy.sparkleShowsScheduledUpdate(immediateFocus: false, notificationsAuthorized: false))
    }
}
