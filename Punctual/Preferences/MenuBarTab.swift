//
//  MenuBarTab.swift
//  Punctual
//
//  The Menu Bar pane: preset cards, the block list with per-block options, the
//  Join chip, quiet-until-close, meeting progress and the one/two-line layout.
//
//  Derived from MeetingBar's status bar preferences, originally:
//    Created by Andrii Leitsius on 13.01.2021.
//    Copyright © 2021 Andrii Leitsius. All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Defaults
import SwiftUI

struct MenuBarTab: View {
    @Default(.menuBarTokens) private var menuBarTokens
    @Default(.menuBarTwoLineLayout) private var menuBarTwoLineLayout

    // Block options, shown in each block's gear popover.
    @Default(.eventTitleIconFormat) private var eventTitleIconFormat
    @Default(.eventTitleFormat) private var eventTitleFormat
    @Default(.statusbarEventTitleLength) private var statusbarEventTitleLength
    @Default(.menuBarCountdownStyle) private var menuBarCountdownStyle
    @Default(.menuBarCountdownLeadMinutes) private var menuBarCountdownLeadMinutes
    @Default(.menuBarDateStyle) private var menuBarDateStyle
    @Default(.menuBarProgressStyle) private var menuBarProgressStyle
    /// The meeting progress indicator; distinct from the day/year `.progress` block.
    @Default(.meetingProgressStyle) private var meetingProgressStyle
    @Default(.menuBarWorldClockTimeZone) private var menuBarWorldClockTimeZone
    @Default(.menuBarWorldClockLabel) private var menuBarWorldClockLabel

    // Quiet-until-close and imminent highlight.
    @Default(.showEventMaxTimeUntilEventEnabled) private var showEventMaxTimeUntilEventEnabled
    @Default(.showEventMaxTimeUntilEventThreshold) private var showEventMaxTimeUntilEventThreshold
    @Default(.menuBarHighlightImminentEvent) private var menuBarHighlightImminentEvent

    // Join chip.
    @Default(.menuBarShowJoinAction) private var menuBarShowJoinAction
    @Default(.menuBarJoinActionLeadMinutes) private var menuBarJoinActionLeadMinutes

    @State private var gearOpenBlock: MenuBarTokenKind?

    /// Every block, showing ones first in their stored order.
    private var blocks: [MenuBarBlock] {
        MenuBarBlockList.blocks(stored: menuBarTokens)
    }

    private var showingKinds: [MenuBarTokenKind] {
        MenuBarBlockList.kinds(stored: menuBarTokens)
    }

    var body: some View {
        PreferencesGroupedForm {
            presetSection
            blocksSection
            joinActionSection
            quietSection
            meetingProgressSection
            linesSection
            PreferencesResetSection(tab: .menuBar)
        }
        // Idempotent launch migration, re-run here because a section reset clears
        // the seeding flag; without it the block list would come back empty.
        .onAppear(perform: MenuBarTimeFormatDefaultsMigration.migrateDefaultsIfNeeded)
    }

    // MARK: - Presets

    /// Preset cards. The selected card is derived from the stored blocks via
    /// `MenuBarPreset.detect`, so "Custom" means "matches no preset".
    private var presetSection: some View {
        Section(header: Text("preferences_menubar_preset_title".loco())) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(MenuBarPreset.allCases, id: \.self) { preset in
                    presetCard(preset)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            helpText("preferences_menubar_preset_help")
        }
    }

    private var selectedPreset: MenuBarPreset {
        MenuBarPreset.detect(tokens: showingKinds)
    }

    @ViewBuilder
    private func presetCard(_ preset: MenuBarPreset) -> some View {
        let isSelected = selectedPreset == preset

        if preset == .custom {
            // Not a button: "Custom" has nothing to apply.
            presetCardBody(preset, isSelected: isSelected)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            Button {
                menuBarTokens = preset.tokens.map(\.rawValue)
                PunctualLogger.preferences.info(
                    "Applied menu-bar preset \(preset.rawValue, privacy: .public)"
                )
            } label: {
                presetCardBody(preset, isSelected: isSelected)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        }
    }

    private func presetCardBody(_ preset: MenuBarPreset, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(presetName(preset))
                .font(.subheadline.weight(.medium))
            if preset != .custom {
                Text(preset.tokens.map(blockName).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color(nsColor: .separatorColor),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .contentShape(Rectangle())
    }

    private func presetName(_ preset: MenuBarPreset) -> String {
        switch preset {
        case .classic: return "preferences_menubar_preset_classic".loco()
        case .minimal: return "preferences_menubar_preset_minimal".loco()
        case .agenda: return "preferences_menubar_preset_agenda".loco()
        case .info: return "preferences_menubar_preset_info".loco()
        case .custom: return "preferences_menubar_preset_custom".loco()
        }
    }

    // MARK: - The blocks

    /// Every block, always listed; blocks that are off are dimmed below the showing ones.
    private var blocksSection: some View {
        Section(header: Text("preferences_menubar_blocks_title".loco())) {
            helpText("preferences_menubar_blocks_help")

            ForEach(Array(blocks.enumerated()), id: \.element.kind) { pair in
                blockRow(pair.element, index: pair.offset)
            }
        }
    }

    private func blockRow(_ block: MenuBarBlock, index: Int) -> some View {
        HStack(spacing: 6) {
            Label(blockName(block.kind), systemImage: blockSymbol(block.kind))
                .foregroundStyle(block.isOn ? .primary : .secondary)

            Spacer()

            if hasGear(block.kind) {
                Button {
                    gearOpenBlock = (gearOpenBlock == block.kind) ? nil : block.kind
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .disabled(!block.isOn)
                .help("preferences_menubar_block_configure".loco())
                .popover(isPresented: gearBinding(for: block.kind)) {
                    blockGearContent(block.kind)
                        .frame(width: 320)
                        .padding(16)
                }
            }

            Button {
                menuBarTokens = MenuBarBlockList.moved(stored: menuBarTokens, kind: block.kind, by: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!block.isOn || index == 0)
            .help("preferences_menubar_block_move_up".loco())

            Button {
                menuBarTokens = MenuBarBlockList.moved(stored: menuBarTokens, kind: block.kind, by: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!block.isOn || index == showingKinds.count - 1)
            .help("preferences_menubar_block_move_down".loco())

            Toggle("", isOn: blockSwitch(block.kind))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .accessibilityLabel(Text(blockName(block.kind)))
        }
    }

    /// Whether the block has options, and so a gear popover.
    private func hasGear(_ kind: MenuBarTokenKind) -> Bool {
        switch kind {
        case .icon, .title, .countdown, .date, .progress, .worldClock:
            return true
        case .clock, .weekNumber:
            return false
        }
    }

    private func gearBinding(for kind: MenuBarTokenKind) -> Binding<Bool> {
        Binding(
            get: { gearOpenBlock == kind },
            set: { isOn in gearOpenBlock = isOn ? kind : nil }
        )
    }

    /// The options for one block, shown in its gear popover.
    @ViewBuilder
    private func blockGearContent(_ kind: MenuBarTokenKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(blockName(kind))
                .font(.headline)
                .foregroundStyle(.primary)

            switch kind {
            case .icon:
                Picker("preferences_menubar_icon_title".loco(), selection: $eventTitleIconFormat) {
                    iconOption(.calendar, labelKey: "preferences_menubar_icon_calendar")
                    iconOption(.appicon, labelKey: "preferences_menubar_icon_app")
                    iconOption(.eventtype, labelKey: "preferences_menubar_icon_service")
                    iconOption(.none, labelKey: "preferences_menubar_icon_none")
                }
                if eventTitleIconFormat == .none {
                    helpText("preferences_menubar_icon_none_help")
                }

            case .title:
                Picker("preferences_menubar_title_title".loco(), selection: $eventTitleFormat) {
                    Text("preferences_menubar_title_event".loco()).tag(EventTitleFormat.show)
                    Text("preferences_menubar_title_generic".loco()).tag(EventTitleFormat.generic)
                    Text("preferences_menubar_title_dot".loco()).tag(EventTitleFormat.dot)
                    Text("preferences_menubar_title_none".loco()).tag(EventTitleFormat.none)
                }
                Divider()
                Text("preferences_menubar_title_shorten_title".loco())
                    .font(.subheadline.weight(.medium))
                PresetNumberPicker(
                    presets: [20, 30, 50, 80],
                    presetLabel: { "\($0)" },
                    customLabel: "preferences_preset_custom".loco(),
                    value: $statusbarEventTitleLength,
                    range: statusbarEventTitleLengthLimits.min ... statusbarEventTitleLengthLimits.max,
                    step: 5,
                    stepperLabel: { "preferences_menubar_title_shorten_stepper".loco($0) },
                    example: "preferences_menubar_title_shorten_example".loco(),
                    isEnabled: eventTitleFormat == .show
                )

            case .countdown:
                Picker(
                    "preferences_menubar_countdown_style_title".loco(),
                    selection: countdownStyle
                ) {
                    Text("preferences_menubar_countdown_style_compact".loco()).tag(CountdownStyle.compact)
                    Text("preferences_menubar_countdown_style_full".loco()).tag(CountdownStyle.full)
                    Text("preferences_menubar_countdown_style_digital".loco()).tag(CountdownStyle.digital)
                }
                Divider()
                Text("preferences_menubar_countdown_lead_title".loco())
                    .font(.subheadline.weight(.medium))
                PresetNumberPicker(
                    presets: [0, 15, 30, 60, 120],
                    // 0 means "no limit", so it is labelled rather than shown as a number.
                    presetLabel: { $0 == 0 ? "preferences_menubar_countdown_lead_always".loco() : "\($0)" },
                    customLabel: "preferences_preset_custom".loco(),
                    value: $menuBarCountdownLeadMinutes,
                    range: 0 ... 720,
                    step: 5,
                    stepperLabel: { "preferences_menubar_countdown_lead_stepper".loco($0) },
                    example: "preferences_menubar_countdown_lead_example".loco()
                )

            case .date:
                Picker("preferences_menubar_date_style_title".loco(), selection: dateStyle) {
                    Text("preferences_menubar_date_style_weekday".loco()).tag(MenuBarDateStyle.weekday)
                    Text("preferences_menubar_date_style_medium".loco()).tag(MenuBarDateStyle.medium)
                    Text("preferences_menubar_date_style_short".loco()).tag(MenuBarDateStyle.short)
                }

            case .progress:
                Picker("preferences_menubar_progress_style_title".loco(), selection: progressStyle) {
                    Text("preferences_menubar_progress_style_day".loco()).tag(MenuBarProgressStyle.day)
                    Text("preferences_menubar_progress_style_year".loco()).tag(MenuBarProgressStyle.year)
                }

            case .worldClock:
                Picker(
                    "preferences_menubar_world_clock_timezone_title".loco(),
                    selection: $menuBarWorldClockTimeZone
                ) {
                    ForEach(TimeZone.knownTimeZoneIdentifiers.sorted(), id: \.self) { identifier in
                        Text(identifier).tag(identifier)
                    }
                }
                Divider()
                TextField(
                    "preferences_menubar_world_clock_label_title".loco(),
                    text: $menuBarWorldClockLabel,
                    prompt: Text("preferences_menubar_world_clock_label_placeholder".loco())
                )

            case .clock, .weekNumber:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Adds or removes the block from the showing order; its options are kept.
    private func blockSwitch(_ kind: MenuBarTokenKind) -> Binding<Bool> {
        Binding(
            get: { showingKinds.contains(kind) },
            set: { isOn in
                menuBarTokens = MenuBarBlockList.setting(stored: menuBarTokens, kind: kind, isOn: isOn)
            }
        )
    }

    private func blockName(_ kind: MenuBarTokenKind) -> String {
        switch kind {
        case .icon: return "preferences_menubar_block_icon".loco()
        case .title: return "preferences_menubar_block_title".loco()
        case .countdown: return "preferences_menubar_block_countdown".loco()
        case .date: return "preferences_menubar_block_date".loco()
        case .clock: return "preferences_menubar_block_clock".loco()
        case .progress: return "preferences_menubar_block_progress".loco()
        case .weekNumber: return "preferences_menubar_block_week_number".loco()
        case .worldClock: return "preferences_menubar_block_world_clock".loco()
        }
    }

    private func blockSymbol(_ kind: MenuBarTokenKind) -> String {
        switch kind {
        case .icon: return "app"
        case .title: return "textformat"
        case .countdown: return "timer"
        case .date: return "calendar"
        case .clock: return "clock"
        case .progress: return "chart.bar.xaxis"
        case .weekNumber: return "number"
        case .worldClock: return "globe"
        }
    }

    // MARK: - Icon helper (used by the gear popover)

    private func iconOption(_ format: EventTitleIconFormat, labelKey: String) -> some View {
        HStack {
            // `.appicon`'s raw value is the persisted "AppIcon", but the menu
            // bar draws the template glyph for it; preview what will appear.
            Image(nsImage: iconImage(named: format == .appicon ? MenuStyleConstants.appIconName : format.rawValue))
                .resizable()
                .frame(width: 16, height: 16)
            Text(labelKey.loco())
        }
        .tag(format)
    }

    private func iconImage(named name: String) -> NSImage {
        let image = MenuStyleConstants.iconNamed(name)
        image.size = NSSize(width: 16, height: 16)
        return image
    }

    // MARK: - Join chip

    /// The menu bar Join chip and its lead time.
    ///
    /// Not a block: it is a control, always placed last. Its lead time is its own key,
    /// independent of `eventActionHighlightMinutes`.
    private var joinActionSection: some View {
        Section(header: Text("preferences_menubar_join_action_title".loco())) {
            Toggle(
                "preferences_menubar_join_action_toggle".loco(),
                isOn: $menuBarShowJoinAction
            )
            .annotation("preferences_menubar_join_action_help")

            PresetNumberPicker(
                presets: [0, 2, 5, 15],
                // 0 means "only once it starts", so it is labelled rather than shown as a number.
                presetLabel: { $0 == 0 ? "preferences_menubar_join_action_now".loco() : "\($0)" },
                customLabel: "preferences_preset_custom".loco(),
                value: $menuBarJoinActionLeadMinutes,
                range: 0 ... 120,
                step: 1,
                stepperLabel: { "preferences_menubar_join_action_stepper".loco($0) },
                example: "preferences_menubar_join_action_example".loco(),
                isEnabled: menuBarShowJoinAction
            )
        }
    }

    // MARK: - Quiet until a meeting is close

    private var quietSection: some View {
        Section {
            Toggle(
                "preferences_menubar_quiet_toggle".loco(),
                isOn: $showEventMaxTimeUntilEventEnabled
            )

            PresetNumberPicker(
                presets: [15, 30, 60, 120, 240],
                presetLabel: minutesPresetLabel,
                customLabel: "preferences_preset_custom".loco(),
                value: $showEventMaxTimeUntilEventThreshold,
                range: 5 ... 720,
                step: 5,
                stepperLabel: { "preferences_menubar_quiet_stepper".loco($0) },
                example: "preferences_menubar_quiet_example".loco(),
                isEnabled: showEventMaxTimeUntilEventEnabled
            )

            Divider()

            // No threshold here: shares `eventActionHighlightMinutes`, set on the Dropdown pane.
            Toggle(
                "preferences_menubar_highlight_imminent_toggle".loco(),
                isOn: $menuBarHighlightImminentEvent
            )
            .annotation("preferences_menubar_highlight_imminent_help")
        }
    }

    // MARK: - Meeting progress

    /// How the menu bar item shows meeting progress.
    ///
    /// Separate from the `.progress` block, which draws an event-independent day/year bar.
    private var meetingProgressSection: some View {
        Section(header: Text("preferences_menubar_meeting_progress_title".loco())) {
            Picker(
                "preferences_menubar_meeting_progress_style_title".loco(),
                selection: meetingProgressStyleBinding
            ) {
                Text("preferences_menubar_meeting_progress_none".loco())
                    .tag(MeetingProgressStyle.none)
                Text("preferences_menubar_meeting_progress_underline".loco())
                    .tag(MeetingProgressStyle.underline)
                Text("preferences_menubar_meeting_progress_ring".loco())
                    .tag(MeetingProgressStyle.ring)
                Text("preferences_menubar_meeting_progress_capsule".loco())
                    .tag(MeetingProgressStyle.capsule)
                Text("preferences_menubar_meeting_progress_bar".loco())
                    .tag(MeetingProgressStyle.bar)
            }
            .annotation("preferences_menubar_meeting_progress_help")
        }
    }

    /// Bridges the raw-string Default to `MeetingProgressStyle`; unknown values read as `.none`.
    private var meetingProgressStyleBinding: Binding<MeetingProgressStyle> {
        Binding(
            get: { MeetingProgressStyle(rawValue: meetingProgressStyle) ?? .none },
            set: { meetingProgressStyle = $0.rawValue }
        )
    }

    /// A look-ahead preset as a short duration chip: "15m", "1h", "2h".
    private func minutesPresetLabel(_ minutes: Int) -> String {
        minutes < 60
            ? "preferences_preset_minutes_short".loco(minutes)
            : "preferences_preset_hours_short".loco(minutes / 60)
    }

    // MARK: - One line / Two lines

    /// One line, or two lines with the title above the other blocks.
    ///
    /// Disabled while the Meeting title block is off.
    private var linesSection: some View {
        Section {
            Picker("preferences_menubar_lines_title".loco(), selection: $menuBarTwoLineLayout) {
                Text("preferences_menubar_lines_one".loco()).tag(false)
                Text("preferences_menubar_lines_two".loco()).tag(true)
            }
            .disabled(!showingKinds.contains(.title))
        }
    }

    // MARK: - Bindings

    private var countdownStyle: Binding<CountdownStyle> {
        Binding(
            get: { CountdownStyle(rawValue: menuBarCountdownStyle) ?? .full },
            set: { menuBarCountdownStyle = $0.rawValue }
        )
    }

    private var dateStyle: Binding<MenuBarDateStyle> {
        Binding(
            get: { MenuBarDateStyle(rawValue: menuBarDateStyle) ?? .medium },
            set: { menuBarDateStyle = $0.rawValue }
        )
    }

    private var progressStyle: Binding<MenuBarProgressStyle> {
        Binding(
            get: { MenuBarProgressStyle(rawValue: menuBarProgressStyle) ?? .day },
            set: { menuBarProgressStyle = $0.rawValue }
        )
    }

    // MARK: - Helpers

    private func helpText(_ key: String) -> some View {
        PreferencesHelpText(key: key)
    }
}

#Preview {
    MenuBarTab().frame(width: 700, height: 700)
}
