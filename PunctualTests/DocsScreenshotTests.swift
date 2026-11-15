//
//  DocsScreenshotTests.swift
//  Punctual
//
//  Renders every in-app window and pane against sample data (`PreviewFixtures`,
//  never the user's calendar) to PNG for the user guide in `docs/user-guide`.
//  Skipped unless PUNCTUAL_DOCS_SCREENSHOT_DIR is set; run with `make docs-screenshots`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Defaults
import ScreenCaptureKit
import SwiftUI
import XCTest
@testable import Punctual

@MainActor
final class DocsScreenshotTests: BaseTestCase {
    /// The two appearances every surface is captured in, with the file-name suffix for each.
    private static let appearances: [(suffix: String, name: NSAppearance.Name)] = [
        ("light", .aqua),
        ("dark", .darkAqua)
    ]

    private var outputDirectory: URL!
    private var harness: AppModelTestHarness!
    private var calendarSync: CalendarSync!

    /// Skips unless a screenshot run asked for it, then pins the clock and loads the sample calendars.
    ///
    /// Called from each test rather than `setUp`, which `BaseTestCase` declares nonisolated.
    private func prepare() throws {
        guard let dir = ProcessInfo.processInfo.environment["PUNCTUAL_DOCS_SCREENSHOT_DIR"] else {
            throw XCTSkip("PUNCTUAL_DOCS_SCREENSHOT_DIR not set")
        }
        outputDirectory = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // Pinned clock so the sample meetings land on round times.
        PreviewFixtures.pinnedNow = Calendar.current.date(
            bySettingHour: 9, minute: 35, second: 0, of: Date()
        )
        addTeardownBlock { @MainActor in
            PreviewFixtures.pinnedNow = nil
        }

        let calendars = [PreviewFixtures.workCalendar, PreviewFixtures.personalCalendar, PreviewFixtures.focusCalendar]
        harness = AppModelTestHarness(now: PreviewFixtures.now)
        // `model` is lazy and the harness publishers are passthrough subjects: create it
        // first so it is subscribed before anything is sent, or the calendars are dropped.
        _ = harness.model
        harness.publishProviderHealth(ProviderHealth(
            lastSuccessfulRefresh: PreviewFixtures.now,
            lastAttemptedRefresh: PreviewFixtures.now,
            lastSyncedChange: PreviewFixtures.now.addingTimeInterval(-120)
        ))
        harness.publishCalendars(calendars)
        harness.publishSelectedCalendarIDs(calendars.map(\.id))
        harness.publishEvents(PreviewFixtures.sampleEvents)
        calendarSync = CalendarSync(
            provider: FakeEventStore(calendars: calendars, events: PreviewFixtures.sampleEvents)
        )
        settle()
    }

    // MARK: - Preferences

    func testPreferencesPanes() async throws {
        try prepare()
        var selections = PreferencesTab.allCases.map { (slug(for: $0), SidebarSelection.tab($0)) }
        selections.append(("about", .about))
        for (name, selection) in selections {
            try await captureEachAppearance("preferences-\(name)") {
                self.preferencesWindow(PreferencesShellV2(initialSelection: selection))
            }
        }
    }

    func testPreferencesSearch() async throws {
        try prepare()
        try await captureEachAppearance("preferences-search") {
            self.preferencesWindow(PreferencesShellV2(initialSearchQuery: "notification"))
        }
    }

    // MARK: - Onboarding

    func testOnboardingSteps() async throws {
        try prepare()
        let steps: [(String, OnboardingStep)] = [
            ("welcome", .welcome),
            ("authorization", .authorization),
            ("calendars", .calendarSelection),
            ("essentials", .essentials),
            ("done", .success)
        ]
        for (name, step) in steps {
            try await captureEachAppearance("onboarding-\(name)") {
                let handler = OnboardingHandler(
                    onProviderSelected: { _ in
                        // Holds the Authorization step on "Waiting for authorization…" while it is captured.
                        try? await Task.sleep(for: .seconds(60))
                        return .cancelled
                    },
                    onComplete: { _ in .success }
                )
                handler.appModel = self.harness.model
                let view = OnboardingView(initialStep: step, provider: .macOSEventKit)
                    .environmentObject(handler)
                return self.window(
                    view,
                    size: OnboardingWindowPresentationPolicy.contentRect.size,
                    styleMask: [.borderless],
                    title: WindowTitles.onboarding
                )
            }
        }
    }

    // MARK: - Dropdown

    func testDropdownStates() async throws {
        try prepare()
        let variants: [(String, Bool)] = [("dropdown", false), ("dropdown-with-finished", true)]
        for (name, includeFinished) in variants {
            // The dropdown drops ended meetings while this is on, which is the default.
            Defaults[.hideFinishedEventsInMenu] = !includeFinished
            try await captureEachAppearance(name) {
                let state = PreviewFixtures.makeState(includeFinished: includeFinished, includeReminders: true)
                let view = DropdownPanelView(
                    state: state,
                    handlers: DropdownPanelHandlers(),
                    now: PreviewFixtures.now,
                    isPreview: true
                )
                .frame(width: DropdownMetrics.standard.panelWidth)
                .fixedSize(horizontal: false, vertical: true)
                return self.window(view, size: nil, styleMask: [.borderless], title: "")
            }
        }
    }

    // MARK: - Windows

    func testCommandBar() async throws {
        try prepare()
        try await captureEachAppearance("command-bar") {
            let viewModel = CommandBarViewModel(
                handlers: CommandBarHandlers(
                    events: { PreviewFixtures.sampleEvents },
                    send: { _ in },
                    openPreferences: {},
                    createMeeting: {}
                ),
                dismiss: {}
            )
            return self.window(
                CommandBarView(viewModel: viewModel),
                size: CommandBarWindowPresentationPolicy.contentRect.size,
                styleMask: [.borderless],
                title: ""
            )
        }
    }

    func testCalendarWindow() async throws {
        try prepare()
        for mode in [CalendarGridMode.month, .week] {
            try await captureEachAppearance("calendar-window-\(mode == .month ? "month" : "week")") {
                let viewModel = CalendarGridViewModel(
                    handlers: CalendarWindowHandlers(
                        fetchEvents: { _, _ in PreviewFixtures.sampleEvents },
                        join: { _ in }
                    ),
                    now: PreviewFixtures.now,
                    mode: mode
                )
                return self.window(
                    CalendarGridView(viewModel: viewModel),
                    size: CalendarWindowPresentationPolicy.contentRect,
                    title: WindowTitles.calendar
                )
            }
        }
    }

    func testEventEditor() async throws {
        try prepare()
        let modes: [(String, EventEditorMode)] = [
            ("new", .create),
            ("edit", .edit(PreviewFixtures.sampleEvents[0]))
        ]
        for (name, mode) in modes {
            try await captureEachAppearance("event-editor-\(name)") {
                let handlers = EventEditorHandlers(
                    create: { _ in },
                    update: { _, _, _ in },
                    delete: { _, _ in },
                    writableCalendars: { [PreviewFixtures.workCalendar, PreviewFixtures.personalCalendar] },
                    dismiss: {}
                )
                return self.window(
                    EventEditorView(viewModel: EventEditorViewModel(mode: mode, handlers: handlers)),
                    size: EventEditorWindowPresentationPolicy.contentRect,
                    title: WindowTitles.eventEditor
                )
            }
        }
    }

    func testWorldClock() async throws {
        try prepare()
        Defaults[.worldClockPanelZones] = ["America/Los_Angeles", "America/New_York", "Europe/London", "Asia/Tokyo"]
        try await captureEachAppearance("world-clock") {
            self.window(
                WorldClockPanelView(),
                size: WorldClockPanelPresentationPolicy.contentRect,
                title: WindowTitles.worldClock
            )
        }
    }

    func testChangelog() async throws {
        try prepare()
        try await captureEachAppearance("whats-new") {
            self.window(
                ChangelogView(),
                size: ChangelogWindowPresentationPolicy.contentRect.size,
                styleMask: [.borderless],
                title: WindowTitles.changelog
            )
        }
    }

    func testFullscreenNotification() async throws {
        try prepare()
        // Always dark, as in the app.
        let fullscreen = window(
            FullscreenNotification(event: PreviewFixtures.sampleEvents[0], window: nil),
            size: CGSize(width: 1280, height: 800),
            styleMask: [.borderless],
            title: ""
        )
        try await capture(fullscreen, appearance: .darkAqua, to: "fullscreen-notification")
    }

    // MARK: - Helpers

    /// File-name slug for a pane, matching the page names in `docs/user-guide/preferences`.
    private func slug(for tab: PreferencesTab) -> String {
        switch tab {
        case .calendars: "calendars"
        case .filters: "filters"
        case .menuBar: "menu-bar"
        case .dropdown: "dropdown"
        case .calendarWindow: "grid"
        case .joining: "joining"
        case .alerts: "alerts"
        case .general: "general"
        }
    }

    /// The Preferences window as `WindowCoordinator.openPreferencesWindow` builds it.
    private func preferencesWindow(_ shell: PreferencesShellV2) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: PreferencesWindowMetrics.defaultSize),
            styleMask: [.closable, .titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = WindowTitles.preferences
        let toolbar = NSToolbar(identifier: "PunctualPreferencesDocs")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        let controller = NSHostingController(
            rootView: shell
                .environmentObject(harness.model)
                .environmentObject(calendarSync)
        )
        controller.safeAreaRegions = .all
        window.contentViewController = controller
        window.setContentSize(PreferencesWindowMetrics.defaultSize)
        return window
    }

    /// A window hosting `view`. A `nil` size fits the window to the view.
    private func window(
        _ view: some View,
        size: CGSize?,
        styleMask: NSWindow.StyleMask = [.closable, .titled, .miniaturizable],
        title: String
    ) -> NSWindow {
        let host = NSHostingView(rootView: view)
        let frame = NSRect(origin: .zero, size: size ?? host.fittingSize)
        let window = NSWindow(contentRect: frame, styleMask: styleMask, backing: .buffered, defer: false)
        window.title = title
        window.contentView = host
        return window
    }

    private func captureEachAppearance(_ name: String, make: () -> NSWindow) async throws {
        for (suffix, appearance) in Self.appearances {
            try await capture(make(), appearance: appearance, to: "\(name)-\(suffix)")
        }
    }

    /// Set once a window-server capture fails (usually no Screen Recording permission),
    /// so the rest of the run goes straight to the offscreen fallback.
    private static var windowServerCaptureUnavailable = false

    /// Shows `window`, lets SwiftUI lay out and load, and writes it to `<name>.png`.
    ///
    /// Prefers a window-server capture (ScreenCaptureKit), which draws everything the user
    /// sees, including the Preferences sidebar's vibrant rows. It needs Screen Recording
    /// permission for the test host; without it, falls back to `cacheDisplay`, which leaves
    /// vibrant content such as the sidebar list blank.
    private func capture(_ window: NSWindow, appearance: NSAppearance.Name, to name: String) async throws {
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        try await Task.sleep(for: .seconds(0.8))

        var png: Data?
        if !Self.windowServerCaptureUnavailable {
            let result = await Self.windowServerPNG(windowID: CGWindowID(window.windowNumber))
            png = result.png
            if let failure = result.failure {
                Self.windowServerCaptureUnavailable = true
                print("""
                DocsScreenshotTests: ScreenCaptureKit capture failed (\(failure)). Grant Screen Recording \
                to Punctual in System Settings ▸ Privacy & Security and run again. Using offscreen \
                capture for now, which leaves the Preferences sidebar blank.
                """)
            }
        }
        let data = try png ?? offscreenPNG(of: window)
        try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
        window.close()
    }

    /// The window as the window server composites it, title bar included and shadow left out,
    /// as PNG data, or the reason it could not be captured.
    ///
    /// Nonisolated and keyed by window number so no ScreenCaptureKit object crosses actors.
    private nonisolated static func windowServerPNG(windowID: CGWindowID) async -> (png: Data?, failure: String?) {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return (nil, "window \(windowID) was not found")
            }
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let configuration = SCStreamConfiguration()
            configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
            configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            configuration.captureResolution = .best
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return (NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]), nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    /// Draws the window's frame view (title bar included) offscreen.
    private func offscreenPNG(of window: NSWindow) throws -> Data {
        let contentView = try XCTUnwrap(window.contentView)
        let view = window.styleMask.contains(.titled) ? (contentView.superview ?? contentView) : contentView
        view.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    /// Runs the main loop briefly so Combine publishers deliver and async loads finish.
    private func settle(_ seconds: TimeInterval = 0.6) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}
