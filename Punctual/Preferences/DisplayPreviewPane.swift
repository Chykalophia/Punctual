//
//  DisplayPreviewPane.swift
//  Punctual
//
//  The live preview column of the Dropdown pane: a menu bar strip rendered by
//  `StatusBarPresenter.composedPresentation`, and the real `DropdownPanelView`
//  mounted against fixture state.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Defaults
import SwiftUI

/// Live preview of the menu bar item and dropdown that re-renders as settings change.
struct DisplayPreviewPane: View {
    // Menu bar composition and block styles.
    @Default(.menuBarTokens) private var menuBarTokens
    @Default(.menuBarCountdownStyle) private var menuBarCountdownStyle
    @Default(.menuBarDateStyle) private var menuBarDateStyle
    @Default(.menuBarProgressStyle) private var menuBarProgressStyle
    @Default(.menuBarWorldClockTimeZone) private var menuBarWorldClockTimeZone
    @Default(.menuBarWorldClockLabel) private var menuBarWorldClockLabel
    @Default(.timeFormat) private var timeFormat

    // Legacy status bar keys, used by `derivedComposition` when no blocks are stored.
    @Default(.eventTitleIconFormat) private var eventTitleIconFormat
    @Default(.eventTitleFormat) private var eventTitleFormat
    @Default(.eventTimeFormat) private var eventTimeFormat
    @Default(.statusbarEventTitleLength) private var statusbarEventTitleLength

    // Observed only to trigger re-render. Every setting the panel reads must be listed here,
    // or the preview silently goes stale until an unrelated value changes.
    @Default(.hideFinishedEventsInMenu) private var hideFinishedEventsInMenu
    @Default(.showRemindersInMenu) private var showRemindersInMenu
    @Default(.showGreetingInMenu) private var showGreetingInMenu
    @Default(.showAgendaInMenu) private var showAgendaInMenu
    @Default(.showMeetingControlInMenu) private var showMeetingControlInMenu
    @Default(.showJoinSectionInMenu) private var showJoinSectionInMenu
    @Default(.showBookmarksInMenu) private var showBookmarksInMenu
    @Default(.showCalendarInMenu) private var showCalendarInMenu
    @Default(.dropdownModuleOrder) private var dropdownModuleOrder
    @Default(.timelineStyle) private var timelineStyleRaw
    @Default(.dropdownDensity) private var dropdownDensityRaw
    @Default(.meetingCardShowsProgress) private var meetingCardShowsProgress
    @Default(.greetingShowsDate) private var greetingShowsDate
    @Default(.dropdownMaxEventRows) private var dropdownMaxEventRows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("preferences_display_preview_menu_bar_label")
                    menuBarStrip
                        .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("preferences_display_preview_dropdown_label")
                    dropdownPreview
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("preferences_display_preview_title".loco())
                .font(.headline)
            Text("preferences_display_preview_caption".loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
    }

    private func sectionLabel(_ key: String) -> some View {
        Text(key.loco())
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
    }

    // MARK: - Menu-bar strip

    /// A rounded strip standing in for the menu bar, with the item pinned to the trailing edge.
    private var menuBarStrip: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 12)
            chip(for: menuBarPresentation)
        }
        .padding(.trailing, 8)
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
    }

    @ViewBuilder
    private func chip(for presentation: StatusBarPresentation) -> some View {
        HStack(spacing: 4) {
            if presentation.iconPosition == .leading {
                icon(presentation.icon)
            }
            if !presentation.title.isEmpty {
                Text(presentation.title)
                    .font(.system(size: MenuStyleConstants.defaultFontSize))
                    .foregroundStyle(.primary)
            }
            if presentation.iconPosition == .trailing {
                icon(presentation.icon)
            }
        }
    }

    @ViewBuilder
    private func icon(_ icon: StatusBarIcon) -> some View {
        switch icon {
        case .asset(let name):
            Image(nsImage: MenuStyleConstants.iconNamed(name))
                .resizable()
                .frame(width: 16, height: 16)
        case .meetingService(let service):
            Image(nsImage: getIconForMeetingService(service))
                .resizable()
                .frame(width: 16, height: 16)
        case .none:
            EmptyView()
        }
    }

    /// The menu bar presentation for a sample event, independent of the user's calendar state.
    private var menuBarPresentation: StatusBarPresentation {
        let now = Date()
        var calendar = Calendar.current
        calendar.locale = I18N.instance.locale
        let sample = StatusBarEventPresentationInput(
            title: PreviewFixtures.sampleEvents.first?.title ?? "",
            startDate: now.addingTimeInterval(25 * 60),
            endDate: now.addingTimeInterval(55 * 60),
            meetingService: .zoom,
            participation: .normal
        )
        return StatusBarPresenter.composedPresentation(
            nextEvent: sample,
            composition: menuBarTokens.isEmpty ? derivedComposition : previewComposition,
            settings: previewComposedSettings,
            now: now,
            calendar: calendar
        )
    }

    /// The stored blocks, parsed and de-duplicated; mirrors `MenuBarComposition.currentIfEnabled`
    /// but reads the observed key.
    private var previewComposition: MenuBarComposition {
        var seen = Set<MenuBarTokenKind>()
        let tokens = menuBarTokens
            .compactMap(MenuBarTokenKind.init(rawValue:))
            .filter { seen.insert($0).inserted }
        return tokens.isEmpty ? derivedComposition : MenuBarComposition(tokens: tokens)
    }

    /// Composition derived from the legacy keys, used when no blocks are stored; mirrors
    /// `MenuBarComposition.derivedFromLegacy` but reads the observed keys.
    private var derivedComposition: MenuBarComposition {
        var tokens: [MenuBarTokenKind] = []
        if eventTitleIconFormat != .none { tokens.append(.icon) }
        if eventTitleFormat != .none { tokens.append(.title) }
        if eventTimeFormat != .hide { tokens.append(.countdown) }
        return tokens.isEmpty ? .standard : MenuBarComposition(tokens: tokens)
    }

    /// Mirrors `MenuBarComposedSettings.current` but reads through the observed
    /// `@Default` wrappers and forces a representative next-event mode.
    private var previewComposedSettings: MenuBarComposedSettings {
        MenuBarComposedSettings(
            presentation: StatusBarPresentationSettings(
                hasSelectedCalendars: true,
                showEventMaxTimeUntilEventEnabled: false,
                showEventMaxTimeUntilEventThreshold: 0
            ),
            title: StatusBarTitleSettings(
                titleFormat: StatusBarEventTitleFormat(eventTitleFormat),
                titleLength: statusbarEventTitleLength,
                labels: .current
            ),
            countdownStyle: CountdownStyle(rawValue: menuBarCountdownStyle) ?? .full,
            dateStyle: MenuBarDateStyle(rawValue: menuBarDateStyle) ?? .medium,
            progressStyle: MenuBarProgressStyle(rawValue: menuBarProgressStyle) ?? .day,
            use24HourClock: timeFormat == .military,
            worldClockTimeZone: TimeZone(identifier: menuBarWorldClockTimeZone) ?? .current,
            worldClockLabel: menuBarWorldClockLabel,
            weekNumberPrefix: "menu_bar_week_number_prefix".loco(),
            iconFormat: StatusBarIconFormat(eventTitleIconFormat),
            iconFormatAssetName: eventTitleIconFormat.rawValue,
            iconAssets: .production,
            tokenSeparator: "  ",
            pendingDisplay: .normal,
            tentativeDisplay: .normal
        )
    }

    // MARK: - Dropdown preview (the REAL panel)

    /// The real `DropdownPanelView` on fixture state, with no-op handlers and hit testing off.
    private var dropdownPreview: some View {
        let state = PreviewFixtures.makeState(
            includeFinished: !hideFinishedEventsInMenu,
            includeReminders: showRemindersInMenu
        )

        return DropdownPanelView(
            state: state,
            handlers: DropdownPanelHandlers(),
            now: PreviewFixtures.now,
            isPreview: true
        )
        .allowsHitTesting(false)
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
    }
}

#Preview {
    DisplayPreviewPane()
        .frame(width: 340, height: 620)
}
