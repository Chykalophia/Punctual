//
//  Preferences.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 14.05.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
import SwiftUI

/// What the sidebar currently points at: a settings pane, or the About & Support footer item.
enum PreferencesSelection: Hashable {
    case tab(PreferencesTab)
    case aboutSupport
}

struct PreferencesView: View {
    @State private var selection: PreferencesSelection = .tab(.defaultSelection)
    @State private var searchQuery = ""
    // Pinned to `.all` with the sidebar toggle removed, so the sidebar cannot collapse.
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    private let navigation = PreferencesNavigation.shared

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 225, ideal: 235, max: 260)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Minimum that fits the Dropdown pane's settings plus its ~340pt preview.
        .frame(minWidth: 860, minHeight: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: navigation.requestedTab) { _, requested in
            guard let requested else { return }
            selection = .tab(requested)
            searchQuery = ""
            navigation.requestedTab = nil
        }
    }

    // MARK: - Sidebar

    /// Flat list of panes with a search field on top and the About footer below.
    ///
    /// The `List` must stay the root view so it keeps the sidebar role; wrapping it
    /// in a stack loses the sidebar styling. Labels take no custom `foregroundStyle`,
    /// which would override the selection pill's contrasting colour. Search is a
    /// safe-area inset, not `.searchable`, whose toolbar overlaps the first rows.
    private var sidebar: some View {
        List(selection: tabSelection) {
            ForEach(PreferencesTab.allCases) { tab in
                Label(tab.titleKey.loco(), systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                aboutFooterItem
            }
            .background(.bar)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                TextField(
                    "preferences_search_placeholder".loco(),
                    text: $searchQuery
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.bar)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }

    /// Bridges the two-case selection to the `List`'s single-type selection:
    /// picking the footer item deselects every row.
    private var tabSelection: Binding<PreferencesTab?> {
        Binding(
            get: {
                if case .tab(let tab) = selection { return tab }
                return nil
            },
            set: { newValue in
                if let newValue { selection = .tab(newValue) }
            }
        )
    }

    private var aboutFooterItem: some View {
        let isSelected = selection == .aboutSupport
        return Button {
            selection = .aboutSupport
        } label: {
            Label("preferences_tab_about".loco(), systemImage: "info.circle")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if !trimmedQuery.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                PreferencesDetailHeader(
                    title: "preferences_search_results_title".loco(trimmedQuery)
                )
                SettingsSearchResults(query: trimmedQuery) { entry in
                    selection = .tab(entry.tab)
                    searchQuery = ""
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            switch selection {
            case .tab(let tab):
                VStack(alignment: .leading, spacing: 0) {
                    PreferencesDetailHeader(
                        title: tab.titleKey.loco(),
                        purpose: tab.purposeKey.loco()
                    )
                    preferencesTabContent(tab)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .aboutSupport:
                VStack(alignment: .leading, spacing: 0) {
                    PreferencesDetailHeader(title: "preferences_tab_about".loco())
                    AboutSupportView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

/// The pane title and one-line purpose shown at the top of the detail column.
///
/// Used instead of `.navigationTitle`, whose navigation bar clips content in a plain `NSWindow`.
private struct PreferencesDetailHeader: View {
    let title: String
    var purpose: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let purpose {
                Text(purpose)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }
}

/// Builds the detail content for a preferences pane.
@MainActor
@ViewBuilder
private func preferencesTabContent(_ tab: PreferencesTab) -> some View {
    switch tab {
    case .calendars:
        CalendarsTab()
    case .filters:
        FiltersTab()
    case .menuBar:
        MenuBarTab()
    case .dropdown:
        DropdownTab()
    case .calendarWindow:
        CalendarWindowTab()
    case .joining:
        JoiningTab()
    case .alerts:
        AlertsTab()
    case .general:
        GeneralTab()
    }
}

/// Returns the localized label for `key` with any trailing colon (ASCII or full-width) removed.
func preferenceLabel(_ key: String) -> String {
    var label = key.loco().trimmingCharacters(in: .whitespaces)
    while let last = label.last, last == ":" || last == "：" {
        label.removeLast()
    }
    return label
}

/// Shared grouped-form container for preferences panes, matching System Settings.
///
/// `ForEach(...).onMove` is inert inside a `Form`, so reordering uses explicit buttons.
/// The unbounded `.frame` is required: without it the form sizes to its content inside
/// the detail `VStack`, overflows the window, and never scrolls.
struct PreferencesGroupedForm<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .focusSection()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PreferencesView()
        .frame(width: 1180, height: 680)
}
