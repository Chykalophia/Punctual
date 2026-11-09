//
//  PreferencesPanes.swift
//  Punctual
//
//  Thin pane wrappers (Dropdown, Calendar Window) and the About & Support view.
//  Panes with substantial content live in their own files.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import SwiftUI

// MARK: - Filters

// MARK: - Menu Bar

// MARK: - Dropdown

/// The Dropdown pane: settings on the left and, when the window is wide enough,
/// a live preview of the real `DropdownPanelView` on the right.
struct DropdownTab: View {
    /// Fixed width of the preview column: the dropdown panel width plus a gutter.
    private static let previewWidth = DropdownMetrics.standard.panelWidth + 10

    /// Narrowest the form can be before its widest control (the five-segment
    /// picker in `DropdownDisplaySection`) is crushed.
    private static let formMinimumWidth: CGFloat = 400

    /// Detail width below which the preview is hidden instead of truncating the form.
    static var minimumTwoColumnWidth: CGFloat {
        formMinimumWidth + previewWidth
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                PreferencesGroupedForm {
                    if !showsPreview(detailWidth: proxy.size.width) {
                        Section {
                            PreferenceCallout(
                                systemImage: "arrow.left.and.right",
                                message: "preferences_dropdown_preview_hidden_hint".loco(),
                                tint: .secondary
                            )
                        }
                    }
                    DropdownComposerSection()
                    DropdownDisplaySection()
                    PreferencesResetSection(tab: .dropdown)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showsPreview(detailWidth: proxy.size.width) {
                    DisplayPreviewPane()
                        .frame(width: Self.previewWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color(nsColor: .separatorColor))
                                .frame(width: 1)
                        }
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.15), value: showsPreview(detailWidth: proxy.size.width))
        }
    }

    /// Whether the detail column is wide enough for both the form and the preview.
    private func showsPreview(detailWidth: CGFloat) -> Bool {
        detailWidth >= Self.minimumTwoColumnWidth
    }
}

// MARK: - Calendar Window

/// The Calendar Window pane: settings for the app's own month/week window, not Apple's Calendar.
struct CalendarWindowTab: View {
    var body: some View {
        PreferencesGroupedForm {
            CalendarWindowDisplaySection()
            PreferencesResetSection(tab: .calendarWindow)
        }
    }
}

// MARK: - Joining / Alerts

// MARK: - About & Support

/// App info, links, diagnostics copy and software updates, shown from the sidebar footer.
///
/// Not a `PreferencesTab` case, and not a `PreferencesGroupedForm`: it is a card, not a settings list.
struct AboutSupportView: View {
    @EnvironmentObject var appModel: AppModel

    /// Shows the transient "Copied" confirmation beside the diagnostics button.
    @State private var didCopyDiagnostics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PreferencesCard {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 16) {
                            Image("appIconForAbout")
                                .resizable()
                                .frame(width: 72, height: 72)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text("Punctual")
                                        .font(.title2).bold()
                                    Text(version)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                Text("preferences_about_description".loco())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                        }

                        Divider()

                        HStack(spacing: 16) {
                            Button("GitHub") {
                                Links.github.openInDefaultBrowser()
                            }
                            .buttonStyle(.link)
                            Button("preferences_about_contact".loco()) {
                                Links.emailMe.openInDefaultBrowser()
                            }
                            .buttonStyle(.link)
                            Button("preferences_about_whats_new".loco()) {
                                NSApplication.shared.sendAction(
                                    #selector(AppDelegate.openChangelogWindow(_:)), to: nil, from: nil
                                )
                            }
                            .buttonStyle(.link)
                            Spacer()
                            if didCopyDiagnostics {
                                Label(
                                    "preferences_about_copied".loco(),
                                    systemImage: "checkmark.circle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .transition(.opacity)
                                .accessibilityAddTraits(.isStaticText)
                            }
                            Button("preferences_about_copy_report".loco()) {
                                copyDiagnostics()
                            }
                            .controlSize(.small)
                        }
                        .animation(.easeOut(duration: 0.15), value: didCopyDiagnostics)
                    }
                }
                SoftwareUpdateCard()
            }
            .padding(20)
        }
    }

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private func copyDiagnostics() {
        Task {
            await DiagnosticsClipboard.copy(
                snapshot: DiagnosticsSnapshot(appState: appModel.state)
            )
            didCopyDiagnostics = true
            try? await Task.sleep(for: .seconds(2))
            didCopyDiagnostics = false
        }
    }
}
