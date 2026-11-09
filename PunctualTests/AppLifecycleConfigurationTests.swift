//
//  AppLifecycleConfigurationTests.swift
//  Punctual
//
//  Pins the built app's Info.plist settings that decide whether macOS may quit Punctual on its own.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import XCTest

@testable import Punctual

final class AppLifecycleConfigurationTests: XCTestCase {
    /// macOS sees a menu-bar app as idle almost all the time, so automatic termination could quit it
    /// mid sign-in. It must stay off.
    func testAutomaticTerminationIsOff() {
        let value = Bundle.main.object(forInfoDictionaryKey: "NSSupportsAutomaticTermination") as? Bool
        XCTAssertEqual(value, false, "Punctual must not let macOS auto-quit it")
    }

    func testRunsAsAMenuBarAgent() {
        // The premise of the test above: an agent (no Dock icon) has no visible
        // window most of the time, which is exactly when auto-quit applies.
        let value = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool
        XCTAssertEqual(value, true)
    }
}
