//
//  GeneralTab.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 13.01.2021.
//  Copyright © 2021 Andrii Leitsius. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
//  The General pane: app-wide settings, keyboard shortcuts and troubleshooting.
//

import SwiftUI

import Defaults
import KeyboardShortcuts
import LaunchAtLogin

struct GeneralTab: View {
    @Default(.timeFormat) var timeFormat
    @Default(.locationAutocompleteEnabled) var locationAutocompleteEnabled

    var body: some View {
        PreferencesGroupedForm {
            Section {
                // Enables a network request; the help text states what data leaves the Mac.
                Toggle(
                    preferenceLabel("preferences_general_location_autocomplete_toggle"),
                    isOn: $locationAutocompleteEnabled
                )
                Text("preferences_general_location_autocomplete_help".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                LaunchAtLogin.Toggle {
                    Text("preferences_general_login_toggle".loco())
                }

                Picker(
                    "preferences_general_time_format_title".loco(),
                    selection: $timeFormat
                ) {
                    Text("preferences_general_time_format_12_hour".loco())
                        .tag(TimeFormat.am_pm)
                    Text("preferences_general_time_format_24_hour".loco())
                        .tag(TimeFormat.military)
                }
                .annotation("preferences_general_time_format_help")
            }

            ShortcutsSection()

            TroubleshootingSection()
        }
    }
}

// MARK: - Keyboard shortcuts

/// Global keyboard shortcuts, grouped by task, with a description where the label is ambiguous.
struct ShortcutsSection: View {
    var body: some View {
        Section(header: Text("preferences_general_shortcuts_title".loco())) {
            ShortcutGroupLabel(titleKey: "preferences_general_shortcuts_open_group")
            ShortcutRow(
                titleKey: "preferences_general_shortcut_open_dropdown",
                recorder: KeyboardShortcuts.Recorder(for: .openMenuShortcut)
            )
            ShortcutRow(
                titleKey: "preferences_general_shortcut_open_calendar_window",
                helpKey: "preferences_general_shortcut_open_calendar_window_help",
                recorder: KeyboardShortcuts.Recorder(for: .calendarShortcut)
            )
            ShortcutRow(
                titleKey: "preferences_general_shortcut_open_search_bar",
                helpKey: "preferences_general_shortcut_open_search_bar_help",
                recorder: KeyboardShortcuts.Recorder(for: .commandBarShortcut)
            )
            ShortcutRow(
                titleKey: "preferences_general_shortcut_open_world_clock",
                recorder: KeyboardShortcuts.Recorder(for: .worldClockShortcut)
            )
        }

        Section {
            ShortcutGroupLabel(titleKey: "preferences_general_shortcuts_join_group")
            ShortcutRow(
                titleKey: "preferences_general_shortcut_join_next",
                recorder: KeyboardShortcuts.Recorder(for: .joinEventShortcut)
            )
            ShortcutRow(
                titleKey: "preferences_general_shortcut_join_clipboard",
                recorder: KeyboardShortcuts.Recorder(for: .openClipboardShortcut)
            )
            ShortcutRow(
                titleKey: "preferences_general_shortcut_camera_check",
                recorder: KeyboardShortcuts.Recorder(for: .cameraPreviewShortcut)
            )
        }

        Section {
            ShortcutGroupLabel(titleKey: "preferences_general_shortcuts_make_group")
            ShortcutRow(
                titleKey: "preferences_general_shortcut_create_meeting",
                helpKey: "preferences_general_shortcut_create_meeting_help",
                recorder: KeyboardShortcuts.Recorder(for: .createMeetingShortcut)
            )
            ShortcutRow(
                titleKey: "preferences_general_shortcut_new_event",
                recorder: KeyboardShortcuts.Recorder(for: .newEventShortcut)
            )
        }

        Section {
            ShortcutGroupLabel(titleKey: "preferences_general_shortcuts_privacy_group")
            ShortcutRow(
                titleKey: "preferences_general_shortcut_hide_title",
                helpKey: "preferences_general_shortcut_hide_title_help",
                recorder: KeyboardShortcuts.Recorder(for: .toggleMeetingTitleVisibilityShortcut)
            )
        }
    }
}

private struct ShortcutGroupLabel: View {
    let titleKey: String

    var body: some View {
        Text(titleKey.loco())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

private struct ShortcutRow<Recorder: View>: View {
    let titleKey: String
    var helpKey: String?
    let recorder: Recorder

    var body: some View {
        LabeledContent {
            recorder
        } label: {
            Text(titleKey.loco())
            if let helpKey {
                Text(helpKey.loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Troubleshooting

/// Recovery actions, such as resetting all settings.
private struct TroubleshootingSection: View {
    var body: some View {
        Section {
            PreferencesDisclosure(
                id: "general.troubleshooting",
                titleKey: "preferences_general_troubleshooting_title"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    PreferencesResetAllButton()
                }
                .padding(.top, 4)
            }
        }
    }
}

#Preview() {
    GeneralTab()
        .padding()
        .frame(width: 700, height: 620)
}
