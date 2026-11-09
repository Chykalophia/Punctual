//
//  MarketingScreenshotTests.swift
//  Punctual
//
//  Renders DropdownPanelView against PreviewFixtures to PNG for the website. Skipped unless
//  PUNCTUAL_SCREENSHOT_DIR is set; run with `make screenshots`.
//

import AppKit
import SwiftUI
import XCTest
@testable import Punctual

@MainActor
final class MarketingScreenshotTests: BaseTestCase {
    func testRenderDropdown() throws {
        guard let dir = ProcessInfo.processInfo.environment["PUNCTUAL_SCREENSHOT_DIR"] else {
            throw XCTSkip("PUNCTUAL_SCREENSHOT_DIR not set")
        }
        // Pinned clock so the sample meetings land on round times.
        PreviewFixtures.pinnedNow = Calendar.current.date(
            bySettingHour: 9, minute: 35, second: 0, of: Date()
        )
        defer { PreviewFixtures.pinnedNow = nil }
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let state = PreviewFixtures.makeState(includeFinished: false, includeReminders: true)
            let view = DropdownPanelView(
                state: state,
                handlers: DropdownPanelHandlers(),
                now: PreviewFixtures.now,
                isPreview: true
            )
            .frame(width: DropdownMetrics.standard.panelWidth)
            .fixedSize(horizontal: false, vertical: true)

            let host = NSHostingView(rootView: view)
            host.appearance = NSAppearance(named: appearance)
            let size = host.fittingSize
            host.frame = NSRect(origin: .zero, size: size)

            let window = NSWindow(
                contentRect: host.frame, styleMask: [.borderless],
                backing: .buffered, defer: false
            )
            window.appearance = NSAppearance(named: appearance)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))

            let rep = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try png.write(to: URL(fileURLWithPath: dir).appendingPathComponent("dropdown-\(name).png"))
        }
    }
}
