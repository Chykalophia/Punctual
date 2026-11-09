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
        harness.publishCalendars(calendars)
        harness.publishSelectedCalendarIDs(calendars.map(\.id))
        harness.publishEvents(PreviewFixtures.sampleEvents)
        calendarSync = CalendarSync(
            provider: FakeEventStore(calendars: calendars, events: PreviewFixtures.sampleEvents)
        )
        settle()
    }

    // MARK: - Preferences

    func testPreferencesPanes() throws {
        try prepare()
        var selections = PreferencesTab.allCases.map { (slug(for: $0), SidebarSelection.tab($0)) }
        selections.append(("about", .about))
        for (name, selection) in selections {
            try captureEachAppearance("preferences-\(name)") {
                self.preferencesWindow(PreferencesShellV2(initialSelection: selection))
            }
        }
    }

    func testPreferencesSearch() throws {
        try prepare()
        try captureEachAppearance("preferences-search") {
            self.preferencesWindow(PreferencesShellV2(initialSearchQuery: "notification"))
        }
    }

    // MARK: - Onboarding

    func testOnboardingSteps() throws {
        try prepare()
        let steps: [(String, OnboardingStep)] = [
            ("welcome", .welcome),
            ("authorization", .authorization),
            ("calendars", .calendarSelection),
            ("essentials", .essentials),
            ("done", .success)
        ]
        for (name, step) in steps {
            try captureEachAppearance("onboarding-\(name)") {
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

    func testDropdownStates() throws {
        try prepare()
        let variants: [(String, Bool)] = [("dropdown", false), ("dropdown-with-finished", true)]
        for (name, includeFinished) in variants {
            try captureEachAppearance(name) {
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

    func testCommandBar() throws {
        try prepare()
        try captureEachAppearance("command-bar") {
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

    func testCalendarWindow() throws {
        try prepare()
        for mode in [CalendarGridMode.month, .week] {
            try captureEachAppearance("calendar-window-\(mode == .month ? "month" : "week")") {
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

    func testEventEditor() throws {
        try prepare()
        let modes: [(String, EventEditorMode)] = [
            ("new", .create),
            ("edit", .edit(PreviewFixtures.sampleEvents[0]))
        ]
        for (name, mode) in modes {
            try captureEachAppearance("event-editor-\(name)") {
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

    func testWorldClock() throws {
        try prepare()
        Defaults[.worldClockPanelZones] = ["America/Los_Angeles", "America/New_York", "Europe/London", "Asia/Tokyo"]
        try captureEachAppearance("world-clock") {
            self.window(
                WorldClockPanelView(),
                size: WorldClockPanelPresentationPolicy.contentRect,
                title: WindowTitles.worldClock
            )
        }
    }

    func testChangelog() throws {
        try prepare()
        try captureEachAppearance("whats-new") {
            self.window(
                ChangelogView(),
                size: ChangelogWindowPresentationPolicy.contentRect.size,
                styleMask: [.borderless],
                title: WindowTitles.changelog
            )
        }
    }

    func testFullscreenNotification() throws {
        try prepare()
        // Always dark, as in the app.
        let fullscreen = window(
            FullscreenNotification(event: PreviewFixtures.sampleEvents[0], window: nil),
            size: CGSize(width: 1280, height: 800),
            styleMask: [.borderless],
            title: ""
        )
        try capture(fullscreen, appearance: .darkAqua, to: "fullscreen-notification")
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

    private func captureEachAppearance(_ name: String, make: () -> NSWindow) throws {
        for (suffix, appearance) in Self.appearances {
            try capture(make(), appearance: appearance, to: "\(name)-\(suffix)")
        }
    }

    /// Shows `window` off to the side, lets SwiftUI lay out and load, and writes its frame view
    /// (title bar included) to `<name>.png`.
    private func capture(_ window: NSWindow, appearance: NSAppearance.Name, to name: String) throws {
        window.appearance = NSAppearance(named: appearance)
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        settle()

        let contentView = try XCTUnwrap(window.contentView)
        let view = window.styleMask.contains(.titled) ? (contentView.superview ?? contentView) : contentView
        view.layoutSubtreeIfNeeded()
        let rep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: rep)
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        try png.write(to: outputDirectory.appendingPathComponent("\(name).png"))
        window.orderOut(nil)
        window.close()
    }

    /// Runs the main loop briefly so Combine publishers deliver and async loads finish.
    private func settle(_ seconds: TimeInterval = 0.6) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }
}
