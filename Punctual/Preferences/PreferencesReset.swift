//
//  PreferencesReset.swift
//  Punctual
//
//  "Reset this section" and "Reset all settings…". The keys each pane owns come
//  from `SettingsIndex`, not from this file.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Defaults
import SwiftUI

enum PreferencesReset {
    /// Restores every `Defaults` key the pane owns to its default.
    ///
    /// User data (calendar selection, saved links, browsers) and bookkeeping keys are never
    /// indexed, so never reset. Exception: `menuBarTimeFormatMigrated` is reset with the
    /// blocks it seeded, so the pane returns to its fresh-install state.
    static func reset(_ tab: PreferencesTab) {
        let keys = SettingsIndex.defaultsKeys(in: tab)
        guard !keys.isEmpty else { return }
        Defaults.reset(keys)
        PunctualLogger.preferences.info(
            "Reset section \(tab.rawValue, privacy: .public) (\(keys.count, privacy: .public) keys)"
        )
    }

    /// Restores every setting on every pane.
    static func resetAll() {
        let keys = SettingsIndex.allDefaultsKeys
        Defaults.reset(keys)
        PunctualLogger.preferences.info(
            "Reset all settings (\(keys.count, privacy: .public) keys)"
        )
    }
}

/// The "Reset this section…" row at the end of a pane.
struct PreferencesResetSection: View {
    let tab: PreferencesTab

    @State private var isConfirming = false

    var body: some View {
        Section {
            HStack {
                Spacer()
                Button("preferences_reset_section_button".loco()) {
                    isConfirming = true
                }
                .controlSize(.small)
            }
        }
        .confirmationDialog(
            "preferences_reset_section_title".loco(tab.titleKey.loco()),
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("preferences_reset_confirm".loco(), role: .destructive) {
                PreferencesReset.reset(tab)
            }
            Button("general_cancel".loco(), role: .cancel) {}
        } message: {
            Text("preferences_reset_section_message".loco())
        }
    }
}

/// "Reset all settings…", which lives only in General ▸ Troubleshooting.
struct PreferencesResetAllButton: View {
    @State private var isConfirming = false

    var body: some View {
        HStack {
            Spacer()
            Button("preferences_reset_all_button".loco()) {
                isConfirming = true
            }
        }
        .confirmationDialog(
            "preferences_reset_all_title".loco(),
            isPresented: $isConfirming,
            titleVisibility: .visible
        ) {
            Button("preferences_reset_confirm".loco(), role: .destructive) {
                PreferencesReset.resetAll()
            }
            Button("general_cancel".loco(), role: .cancel) {}
        } message: {
            Text("preferences_reset_all_message".loco())
        }
    }
}
