//
//  WindowCoordinator.swift
//  MeetingBar
//

import AppKit
import Defaults
import SwiftUI

enum FullscreenNotificationScreenSelectionPolicy {
    static func select<Screen>(
        keyWindowScreen: Screen?,
        mainWindowScreen: Screen?,
        mouseScreen: Screen?,
        mainScreen: Screen?,
        screens: [Screen]
    ) -> Screen? {
        keyWindowScreen ?? mainWindowScreen ?? mouseScreen ?? mainScreen ?? screens.first
    }
}

enum FullscreenNotificationKeyboardPolicy {
    static let escapeKeyCode: UInt16 = 53

    static func shouldDismiss(keyCode: UInt16) -> Bool {
        keyCode == escapeKeyCode
    }
}

final class FullscreenNotificationWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if FullscreenNotificationKeyboardPolicy.shouldDismiss(keyCode: event.keyCode) {
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

/// Borderless "What's New" window. Closing it acknowledges the changelog via
/// the close handler.
final class ChangelogWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}

enum ChangelogWindowPresentationPolicy {
    static let contentRect = NSRect(x: 0, y: 0, width: 640, height: 560)
    static let minimumSize = NSSize(width: 560, height: 460)
    static let styleMask: NSWindow.StyleMask = [.resizable]
    static let level: NSWindow.Level = .normal
}

/// Borderless Spotlight-style Command Bar that floats above the frontmost app.
final class CommandBarWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    /// Click-away dismiss, deferred a run-loop turn: closing inside AppKit's
    /// key-change callback over-releases the window.
    override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async { [weak self] in self?.close() }
    }
}

/// Borderless host for the SwiftUI dropdown panel. Behaves like a menu: pop-up-menu
/// level, closes on Escape and click-away, excluded from the window cycle.
final class DropdownPanelWindow: NSWindow {
    /// Called once just before the window closes, then cleared.
    var onClose: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_: Any?) {
        close()
    }

    /// Click-away dismiss, deferred a run-loop turn: closing inside AppKit's
    /// key-change processing over-releases the window (EXC_BAD_ACCESS).
    override func resignKey() {
        super.resignKey()
        #if DEBUG
        // Keeps the panel open for screenshots and inspection; set with
        // `defaults write com.chykalophia.Punctual debugPinDropdownPanel -bool true`.
        if Self.isPinnedForDebugging { return }
        #endif
        DispatchQueue.main.async { [weak self] in self?.close() }
    }

    override func close() {
        let handler = onClose
        onClose = nil
        handler?()
        super.close()
    }

    #if DEBUG
    /// Read once per launch rather than on every focus change.
    static let isPinnedForDebugging = UserDefaults.standard.bool(
        forKey: "debugPinDropdownPanel"
    )
    #endif
}

enum DropdownPanelPresentationPolicy {
    /// Menu level, so the panel is never hidden behind the frontmost app.
    static let level: NSWindow.Level = .popUpMenu

    /// Ignores a reopen this soon after closing: clicking the status item while the
    /// panel is open closes it via `resignKey` before the button action fires.
    static let reopenSuppressionInterval: TimeInterval = 0.3
}

enum CommandBarWindowPresentationPolicy {
    static let width: CGFloat = 640
    static let height: CGFloat = 440
    static let contentRect = NSRect(x: 0, y: 0, width: width, height: height)
    static let level: NSWindow.Level = .floating
    /// Fraction of the screen height, from the top, where the palette is centered.
    static let verticalAnchor: CGFloat = 0.28
}

enum OnboardingWindowPresentationPolicy {
    static let contentRect = NSRect(x: 0, y: 0, width: 760, height: 520)
    static let minimumSize = NSSize(width: 640, height: 460)
    static let styleMask: NSWindow.StyleMask = [.resizable]
    static let level: NSWindow.Level = .normal
    static let isMovableByWindowBackground = true
}

/// The dropdown panel's translucent surface: an `NSVisualEffectView` with
/// `.behindWindow` blending, because a SwiftUI material in a borderless transparent
/// window has nothing to sample.
private enum PanelBackdrop {
    @MainActor
    static func wrap(_ content: NSView, radius: CGFloat) -> NSView {
        // Not `NSGlassEffectView`: glass cannot sample glass, so it flattens the panel's
        // inner `glassEffect` controls. `.menu` matches native menu density.
        let reduceTransparency = NSWorkspace.shared
            .accessibilityDisplayShouldReduceTransparency

        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.blendingMode = .behindWindow
        // The SwiftUI content draws no background, so Reduce Transparency is honored here.
        effect.state = reduceTransparency ? .inactive : .active
        // Rounded by mask image: the window server ignores `masksToBounds` for vibrancy
        // materials, which leaves square corners.
        effect.maskImage = roundedMask(radius: radius)

        // Contrast scrim: behind-window vibrancy takes its lightness from the desktop,
        // so a pale wallpaper would wash out content tuned to the appearance.
        let scrim = PanelScrimView()
        scrim.opacity = reduceTransparency ? 1 : 0.32
        scrim.frame = effect.bounds
        scrim.autoresizingMask = [.width, .height]
        effect.addSubview(scrim)

        content.frame = effect.bounds
        content.autoresizingMask = [.width, .height]
        effect.addSubview(content)
        return effect
    }

    /// A nine-part rounded-rectangle mask; cap insets keep the corner radius at any size.
    @MainActor
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(
            size: NSSize(width: edge, height: edge),
            flipped: false
        ) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: radius,
            left: radius,
            bottom: radius,
            right: radius
        )
        image.resizingMode = .stretch
        return image
    }
}

/// A wash of the window background colour between the vibrancy and the content.
/// Drawn in `updateLayer` so it re-resolves when the appearance changes.
private final class PanelScrimView: NSView {
    var opacity: CGFloat = 0.32 {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(opacity)
            .cgColor
    }
}

private enum WindowStylePolicy {
    @MainActor
    /// - Parameter roundsContentView: pass `false` when the content view already owns
    ///   its rounding (`PanelBackdrop`).
    static func applyRoundedCorners(
        to window: NSWindow,
        radius: CGFloat = 12,
        roundsContentView: Bool = true
    ) {
        // Clear, non-opaque window so AppKit derives the shadow from the SwiftUI content;
        // a layer shadow would be clipped by `masksToBounds`.
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true

        guard roundsContentView, let contentView = window.contentView else { return }

        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = radius
        contentView.layer?.masksToBounds = true
    }
}

/// Owns AppKit window lifecycle for app-level windows. Close-time behavior is
/// supplied by callers as closures.
@MainActor
final class WindowCoordinator {
    /// Frame autosave key for the Preferences window. Renaming it discards saved geometry.
    static let preferencesFrameAutosaveName = "PunctualPreferencesWindow"

    /// Whether the dropdown panel is on screen; lets a deep link open it without toggling.
    var isDropdownPanelOpen: Bool { dropdownPanel != nil }

    /// Called with `true` when the dropdown panel appears and `false` when it closes.
    var onDropdownPanelVisibilityChange: (@MainActor (Bool) -> Void)?

    private weak var preferencesWindow: NSWindow?

    /// Move/resize observers that save the Preferences window frame.
    private var preferencesFrameObservers: [NSObjectProtocol] = []
    private weak var onboardingHandler: OnboardingHandler?
    private weak var commandBarWindow: NSWindow?
    private weak var calendarWindow: NSWindow?
    private weak var worldClockWindow: NSWindow?
    private weak var eventEditorWindow: NSWindow?
    private weak var cameraPreviewWindow: NSWindow?
    /// Held strongly and released a run-loop turn after close: letting AppKit free it
    /// inside `resignKey` over-releases it (EXC_BAD_ACCESS).
    private var dropdownPanel: DropdownPanelWindow?
    private var dropdownPanelClosedAt: Date?

    #if DEBUG
    /// Held for the same reason as `dropdownPanel`, and released the same way.
    private var dropdownInspector: DropdownInspectorWindow?
    private var debugHarness: DebugHarnessWindow?
    #endif

    /// Opens the SwiftUI dropdown panel below the status item, or closes it if open.
    /// - Parameter anchor: the status-item button's rect in screen coordinates.
    func openDropdownPanel(
        state: StatusBarMenuState,
        handlers: DropdownPanelHandlers,
        relativeTo anchor: NSRect
    ) {
        if let existing = dropdownPanel {
            existing.close()
            return
        }
        if let closedAt = dropdownPanelClosedAt,
           Date().timeIntervalSince(closedAt)
           < DropdownPanelPresentationPolicy.reopenSuppressionInterval {
            return
        }

        let window = DropdownPanelWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DropdownPanelView.preferredWidth,
                height: DropdownPanelView.maximumHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        var resolvedHandlers = handlers
        resolvedHandlers.dismiss = { [weak window] in window?.close() }

        window.title = ""
        // Not self-releasing; see `dropdownPanel`.
        window.isReleasedWhenClosed = false
        let contentHeight = installDropdownPanelSurface(
            in: window,
            state: state,
            handlers: resolvedHandlers
        )
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        window.hidesOnDeactivate = false
        window.level = DropdownPanelPresentationPolicy.level
        window.setFrame(
            DropdownPanelPlacement.frame(
                for: anchor,
                panelSize: NSSize(
                    width: DropdownPanelView.preferredWidth,
                    height: contentHeight
                ),
                screen: visibleFrame(containing: anchor)
            ),
            display: false
        )
        window.onClose = { [weak self] in
            self?.dropdownPanelClosedAt = Date()
            self?.onDropdownPanelVisibilityChange?(false)
            // Release on the next run-loop turn; AppKit is still using the window inside `close()`.
            DispatchQueue.main.async { self?.dropdownPanel = nil }
        }

        // Accessory app: activate before keying so the panel takes keyboard focus.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        dropdownPanel = window
        onDropdownPanelVisibilityChange?(true)
    }

    /// Installs the panel backdrop and SwiftUI content into `window`. Shared with the
    /// DEBUG inspector.
    /// - Returns: the content's fitting height.
    @discardableResult
    private func installDropdownPanelSurface(
        in window: NSWindow,
        state: StatusBarMenuState,
        handlers: DropdownPanelHandlers
    ) -> CGFloat {
        // Appearance is pinned on the window, not via `preferredColorScheme`, so the AppKit
        // backdrop follows it too. `nil` follows the system.
        window.appearance = PanelThemePolicy
            .appearance(fromRaw: Defaults[.panelAppearance])
            .nsAppearance

        let hosting = NSHostingView(
            rootView: DropdownPanelView(state: state, handlers: handlers)
        )
        // Hosted inside `PanelBackdrop`; see there for why a SwiftUI material can't do this.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        window.contentView = PanelBackdrop.wrap(
            hosting,
            radius: DropdownPanelView.cornerRadius
        )
        // Recompute the alpha-derived shadow once the translucent content is installed.
        window.invalidateShadow()
        WindowStylePolicy.applyRoundedCorners(
            to: window,
            radius: DropdownPanelView.cornerRadius,
            roundsContentView: false
        )
        return hosting.fittingSize.height
    }

    #if DEBUG
    /// Toggles a DEBUG-only copy of the dropdown panel that does not dismiss on click-away.
    /// - Parameter anchor: the status-item rect, or `nil` for the main screen's top-right.
    func toggleDropdownInspectorWindow(
        state: StatusBarMenuState,
        handlers: DropdownPanelHandlers,
        anchor: NSRect?
    ) {
        if let existing = dropdownInspector {
            existing.close()
            return
        }

        let window = DropdownInspectorWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: DropdownPanelView.preferredWidth,
                height: DropdownPanelView.maximumHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        var resolvedHandlers = handlers
        resolvedHandlers.dismiss = { [weak window] in window?.close() }

        window.title = ""
        window.isReleasedWhenClosed = false
        let contentHeight = installDropdownPanelSurface(
            in: window,
            state: state,
            handlers: resolvedHandlers
        )
        // Movable, unlike the real panel, so it can be checked over other backdrops.
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.level = DropdownInspectorPresentationPolicy.level

        let screen = visibleFrame(containing: anchor ?? .zero)
        let resolvedAnchor = anchor
            ?? DropdownInspectorPresentationPolicy.syntheticAnchor(in: screen)
        window.setFrame(
            DropdownPanelPlacement.frame(
                for: resolvedAnchor,
                panelSize: NSSize(
                    width: DropdownPanelView.preferredWidth,
                    height: contentHeight
                ),
                screen: screen
            ),
            display: false
        )
        window.onClose = { [weak self] in
            DispatchQueue.main.async { self?.dropdownInspector = nil }
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        dropdownInspector = window
    }

    /// Opens the debug harness, or brings it forward if it is already open.
    func openDebugHarnessWindow(handlers: DebugHarnessHandlers) {
        if let existing = debugHarness {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = DebugHarnessWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 720),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "Debug harness"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: DebugHarnessView(handlers: handlers))
        // Floating so it stays visible while you drive the status item.
        window.level = .floating
        window.hidesOnDeactivate = false
        window.center()
        window.onClose = { [weak self] in
            DispatchQueue.main.async { self?.debugHarness = nil }
        }

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        debugHarness = window
    }
    #endif

    /// The visible frame of the screen containing `anchor`, falling back to the main
    /// screen, then to a fixed rect when there is no screen (tests).
    private func visibleFrame(containing anchor: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 875)
    }

    /// Opens the month calendar window, or brings it forward if it is already open.
    /// The window loads its own month of events through `handlers`.
    func openCalendarWindow(handlers: CalendarWindowHandlers) {
        if let calendarWindow {
            if calendarWindow.isMiniaturized {
                calendarWindow.deminiaturize(nil)
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            calendarWindow.makeKeyAndOrderFront(nil)
            calendarWindow.orderFrontRegardless()
            return
        }

        let viewModel = CalendarGridViewModel(handlers: handlers)
        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: CalendarWindowPresentationPolicy.contentRect.width,
                height: CalendarWindowPresentationPolicy.contentRect.height
            ),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = WindowTitles.calendar
        window.contentView = NSHostingView(rootView: CalendarGridView(viewModel: viewModel))
        window.minSize = CalendarWindowPresentationPolicy.minimumSize

        let controller = NSWindowController(window: window)
        controller.showWindow(self)
        window.center()

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        calendarWindow = window
    }

    /// Opens the world-clock window, or brings it forward if it is already open.
    func openWorldClockWindow() {
        if let worldClockWindow {
            if worldClockWindow.isMiniaturized {
                worldClockWindow.deminiaturize(nil)
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            worldClockWindow.makeKeyAndOrderFront(nil)
            worldClockWindow.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: WorldClockPanelPresentationPolicy.contentRect.width,
                height: WorldClockPanelPresentationPolicy.contentRect.height
            ),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = WindowTitles.worldClock
        window.contentView = NSHostingView(rootView: WorldClockPanelView())
        window.minSize = WorldClockPanelPresentationPolicy.minimumSize

        let controller = NSWindowController(window: window)
        controller.showWindow(self)
        window.center()

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        worldClockWindow = window
    }

    /// Opens the camera/mic preview window, or brings it forward if it is already open.
    /// The capture session stops and the camera is released when the window closes.
    func openCameraPreviewWindow(handlers: CameraPreviewHandlers) {
        if let cameraPreviewWindow {
            if cameraPreviewWindow.isMiniaturized {
                cameraPreviewWindow.deminiaturize(nil)
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            cameraPreviewWindow.makeKeyAndOrderFront(nil)
            cameraPreviewWindow.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: CameraPreviewLayout.contentSize.width,
                height: CameraPreviewLayout.contentSize.height
            ),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        var resolvedHandlers = handlers
        resolvedHandlers.dismiss = { [weak window] in window?.close() }

        window.title = WindowTitles.cameraPreview
        window.contentView = NSHostingView(rootView: CameraPreviewView(handlers: resolvedHandlers))
        window.minSize = CameraPreviewLayout.minimumSize

        let controller = NSWindowController(window: window)
        controller.showWindow(self)
        window.center()

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        cameraPreviewWindow = window
    }

    /// Opens the event editor for `mode`, replacing any editor that is already open.
    func openEventEditorWindow(mode: EventEditorMode, handlers: EventEditorHandlers) {
        eventEditorWindow?.close()

        let window = NSWindow(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: EventEditorWindowPresentationPolicy.contentRect.width,
                height: EventEditorWindowPresentationPolicy.contentRect.height
            ),
            styleMask: [.closable, .titled, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        var resolvedHandlers = handlers
        resolvedHandlers.dismiss = { [weak window] in window?.close() }
        let viewModel = EventEditorViewModel(mode: mode, handlers: resolvedHandlers)

        window.title = WindowTitles.eventEditor
        window.contentView = NSHostingView(rootView: EventEditorView(viewModel: viewModel))
        window.minSize = EventEditorWindowPresentationPolicy.minimumSize

        let controller = NSWindowController(window: window)
        controller.showWindow(self)
        window.center()

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        eventEditorWindow = window
    }

    /// Opens the Command Bar, or closes it if open. Self-releasing with no
    /// `NSWindowController`, so the weak ref nils on close and the toggle works.
    func openCommandBarWindow(handlers: CommandBarHandlers) {
        if let existing = commandBarWindow {
            existing.close()
            return
        }

        let window = CommandBarWindow(
            contentRect: CommandBarWindowPresentationPolicy.contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let viewModel = CommandBarViewModel(
            handlers: handlers,
            dismiss: { [weak window] in window?.close() }
        )
        window.title = ""
        window.isReleasedWhenClosed = true
        window.contentView = NSHostingView(rootView: CommandBarView(viewModel: viewModel))
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        WindowStylePolicy.applyRoundedCorners(to: window)
        window.level = CommandBarWindowPresentationPolicy.level
        positionCommandBar(window)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        commandBarWindow = window
    }

    private func positionCommandBar(_ window: NSWindow) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.visibleFrame else {
            window.center()
            return
        }
        let size = window.frame.size
        let originX = frame.midX - size.width / 2
        let originY = frame.maxY - frame.height * CommandBarWindowPresentationPolicy.verticalAnchor - size.height / 2
        window.setFrameOrigin(NSPoint(x: originX, y: max(frame.minY, originY)))
    }

    func openOnboardingWindow(
        appModel: AppModel,
        onProviderSelected:
            @escaping @MainActor (EventStoreProvider) async -> ProviderSelectionResult,
        onComplete:
            @escaping @MainActor (EventStoreProvider) async -> ProviderSelectionResult
    ) {
        let handler = OnboardingHandler(
            onProviderSelected: onProviderSelected,
            onComplete: onComplete
        )
        handler.appModel = appModel
        onboardingHandler = handler
        let contentView = OnboardingView().environmentObject(handler)
        let onboardingWindow = OnboardingWindow(
            contentRect: OnboardingWindowPresentationPolicy.contentRect,
            styleMask: OnboardingWindowPresentationPolicy.styleMask,
            backing: .buffered,
            defer: false
        )

        onboardingWindow.title = WindowTitles.onboarding
        onboardingWindow.contentView = NSHostingView(rootView: contentView)
        onboardingWindow.minSize = OnboardingWindowPresentationPolicy.minimumSize
        onboardingWindow.isMovableByWindowBackground =
            OnboardingWindowPresentationPolicy.isMovableByWindowBackground
        WindowStylePolicy.applyRoundedCorners(to: onboardingWindow)
        let controller = NSWindowController(window: onboardingWindow)
        controller.showWindow(self)

        // Normal level so it doesn't cover the browser during provider authorization.
        onboardingWindow.level = OnboardingWindowPresentationPolicy.level
        onboardingWindow.center()
        // Accessory app: without activating, the window isn't key and accent buttons
        // render without their fill.
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow.makeKeyAndOrderFront(nil)
        // `activate` is async for an accessory app, so force the initial ordering.
        onboardingWindow.orderFrontRegardless()
    }

    func openChangelogWindow() {
        let contentView = ChangelogView()
        let changelogWindow = ChangelogWindow(
            contentRect: ChangelogWindowPresentationPolicy.contentRect,
            styleMask: ChangelogWindowPresentationPolicy.styleMask,
            backing: .buffered,
            defer: false
        )
        changelogWindow.title = WindowTitles.changelog
        changelogWindow.contentView = NSHostingView(rootView: contentView)
        changelogWindow.minSize = ChangelogWindowPresentationPolicy.minimumSize
        changelogWindow.isMovableByWindowBackground = true
        WindowStylePolicy.applyRoundedCorners(to: changelogWindow)

        let controller = NSWindowController(window: changelogWindow)
        controller.showWindow(self)

        changelogWindow.level = ChangelogWindowPresentationPolicy.level
        changelogWindow.center()
        NSApp.activate(ignoringOtherApps: true)
        changelogWindow.makeKeyAndOrderFront(nil)
        changelogWindow.orderFrontRegardless()
    }

    func openFullscreenNotificationWindow(event: MBEvent) {
        let screens = NSScreen.screens
        let mouseScreen = screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        let screen = FullscreenNotificationScreenSelectionPolicy.select(
            keyWindowScreen: NSApp.keyWindow?.screen,
            mainWindowScreen: NSApp.mainWindow?.screen,
            mouseScreen: mouseScreen,
            mainScreen: NSScreen.main,
            screens: screens
        )
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let window = FullscreenNotificationWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.contentView = NSHostingView(
            rootView: FullscreenNotification(event: event, window: window))
        window.appearance = NSAppearance(named: .darkAqua)
        window.collectionBehavior = .moveToActiveSpace

        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.title = "Meetingbar Fullscreen Notification"
        window.level = .screenSaver

        let controller = NSWindowController(window: window)
        controller.showWindow(self)

        window.setFrame(screenFrame, display: true)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func openPreferencesWindow(
        appModel: AppModel?,
        calendarSync: CalendarSync?
    ) {
        guard let appModel, let calendarSync else { return }
        let contentView = PreferencesShellV2()
            .environmentObject(appModel)
            .environmentObject(calendarSync)

        if let preferencesWindow {
            if preferencesWindow.isMiniaturized {
                preferencesWindow.deminiaturize(nil)
            }
            NSApplication.shared.activate(ignoringOtherApps: true)
            preferencesWindow.makeKeyAndOrderFront(nil)
            // `activate` is async for an accessory app, so force the window to the front.
            preferencesWindow.orderFrontRegardless()
            return
        }

        // Keep `PreferencesWindowMetrics` in step with the `.frame` in `PreferencesShellV2`.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: PreferencesWindowMetrics.defaultSize.width,
                                height: PreferencesWindowMetrics.defaultSize.height),
            styleMask: [.closable, .titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = PreferencesWindowMetrics.minimumSize
        window.maxSize = PreferencesWindowMetrics.maximumSize

        window.title = WindowTitles.preferences
        window.titleVisibility = .visible

        // An empty unified toolbar gives the titlebar its system background and
        // scroll-edge effect, so scrolled content doesn't run under the title.
        let toolbar = NSToolbar(identifier: "PunctualPreferences")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unified
        window.titlebarAppearsTransparent = false

        // NSHostingController, not NSHostingView: only the controller propagates safe-area
        // insets, which NavigationSplitView needs to clear the titlebar.
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.safeAreaRegions = .all
        window.contentViewController = hostingController

        // Must follow `contentViewController`, which resizes the window to the SwiftUI
        // content's minimum fitting size.
        window.setContentSize(PreferencesWindowMetrics.defaultSize)

        let controller = NSWindowController(window: window)
        controller.showWindow(self)

        // Save the frame on every move and resize so a crash doesn't lose it. Registered
        // before the restore so the first-run `center()` is persisted too.
        preferencesWindow = window
        preferencesFrameObservers.forEach(NotificationCenter.default.removeObserver)
        preferencesFrameObservers = [
            NSWindow.didMoveNotification,
            NSWindow.didResizeNotification
        ].map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: window,
                queue: .main
            // Reads the window off `self` because `Notification` isn't `Sendable`.
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.preferencesWindow?
                        .saveFrame(usingName: Self.preferencesFrameAutosaveName)
                }
            }
        }

        if !window.setFrameUsingName(Self.preferencesFrameAutosaveName) {
            window.center()
            window.saveFrame(usingName: Self.preferencesFrameAutosaveName)
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        // `activate` is async for an accessory app, so force the window to the front.
        window.orderFrontRegardless()

        preferencesWindow = window
    }

    func handleWindowClosed(
        _ window: NSWindow?,
        onboardingCompleted: Bool,
        onIncompleteOnboardingClosed: () -> Void,
        onChangelogClosed: () -> Void
    ) {
        // Saved explicitly on close: `setFrameAutosaveName` never persisted this window.
        if let window, window === preferencesWindow {
            window.saveFrame(usingName: Self.preferencesFrameAutosaveName)
        }

        handleWindowClosed(
            title: window?.title,
            onboardingCompleted: onboardingCompleted,
            onIncompleteOnboardingClosed: onIncompleteOnboardingClosed,
            onChangelogClosed: onChangelogClosed
        )
    }

    func handleWindowClosed(
        title windowTitle: String?,
        onboardingCompleted: Bool,
        onIncompleteOnboardingClosed: () -> Void,
        onChangelogClosed: () -> Void
    ) {
        guard let windowTitle else { return }

        if windowTitle == WindowTitles.onboarding, !onboardingCompleted {
            onIncompleteOnboardingClosed()
        } else if windowTitle == WindowTitles.changelog {
            onChangelogClosed()
        }
    }
}
