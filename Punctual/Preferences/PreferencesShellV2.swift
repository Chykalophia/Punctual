//
//  PreferencesShellV2.swift
//  Punctual
//
//  The Preferences window content: a fixed-width sidebar with search, and the
//  selected pane as the detail. Hosted in a plain `NSWindow` built by
//  `WindowCoordinator.openPreferencesWindow`, not a SwiftUI `Settings` scene.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import SwiftUI

/// Size range of the Preferences window, shared by `WindowCoordinator` and `PreferencesShellV2`.
///
/// Both must agree: a content frame narrower than the window's minimum leaves dead
/// margin, and one wider than its maximum clips.
enum PreferencesWindowMetrics {
    /// Fixed sidebar width (System Settings uses 215pt). The detail column is the window width minus this.
    static let sidebarWidth: CGFloat = 215

    /// Default window size: wide enough for the Dropdown pane to show its preview.
    static var defaultSize: CGSize {
        CGSize(
            width: sidebarWidth + DropdownTab.minimumTwoColumnWidth + breathingRoom,
            height: 680
        )
    }

    /// Margin above the preview threshold so rounding cannot hide the preview at launch.
    private static let breathingRoom: CGFloat = 100

    static let minimumSize = CGSize(width: 840, height: 520)
    static let maximumSize = CGSize(width: 1400, height: 900)
}

enum SidebarSelection: Hashable {
    case tab(PreferencesTab)
    case about

    var navigationTitle: String {
        switch self {
        case .tab(let tab):
            return tab.titleKey.loco()
        case .about:
            return "preferences_tab_about".loco()
        }
    }
}

struct PreferencesShellV2: View {
    @State private var selection: SidebarSelection
    @State private var searchQuery: String
    @Environment(\.colorScheme) private var colorScheme
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    private let navigation = PreferencesNavigation.shared

    /// - Parameters:
    ///   - initialSelection: The pane shown first. The user guide's screenshots open each pane in turn.
    ///   - initialSearchQuery: Text already in the settings search field.
    init(
        initialSelection: SidebarSelection = .tab(.defaultSelection),
        initialSearchQuery: String = ""
    ) {
        _selection = State(initialValue: initialSelection)
        _searchQuery = State(initialValue: initialSearchQuery)
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        !trimmedQuery.isEmpty
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(
                    min: PreferencesWindowMetrics.sidebarWidth,
                    ideal: PreferencesWindowMetrics.sidebarWidth,
                    max: PreferencesWindowMetrics.sidebarWidth
                )
                .toolbar(removing: .sidebarToggle)
        } detail: {
            detail
        }
        .navigationTitle(isSearching ? "preferences_search_results_title".loco(trimmedQuery) : selection.navigationTitle)
        // `ideal*` is required: with only min/max, the hosting controller sizes the window to the minimum.
        .frame(
            minWidth: PreferencesWindowMetrics.minimumSize.width,
            idealWidth: PreferencesWindowMetrics.defaultSize.width,
            maxWidth: PreferencesWindowMetrics.maximumSize.width,
            minHeight: PreferencesWindowMetrics.minimumSize.height,
            idealHeight: PreferencesWindowMetrics.defaultSize.height,
            maxHeight: PreferencesWindowMetrics.maximumSize.height
        )
        .onChange(of: navigation.requestedTab) { _, requested in
            guard let requested else { return }
            selection = .tab(requested)
            searchQuery = ""
            navigation.requestedTab = nil
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: sidebarSelection) {
            Section {
                ForEach(PreferencesTab.allCases) { tab in
                    Label(tab.titleKey.loco(), systemImage: tab.systemImage)
                        .tag(SidebarSelection.tab(tab))
                }
            }

            Section {
                Label("preferences_tab_about".loco(), systemImage: "info.circle")
                    .tag(SidebarSelection.about)
            }
        }
        .listStyle(.sidebar)
        .scrollDisabled(true)
        // Hard frame on top of the column width: AppKit can restore a persisted divider position over the latter.
        .frame(width: PreferencesWindowMetrics.sidebarWidth)
        // An inset, not a list row (a row's section spacing pushes it below the traffic lights).
        // Horizontal padding matches the sidebar row inset so the icon aligns with the rows.
        .safeAreaInset(edge: .top, spacing: 0) {
            searchField
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
        }
    }

    /// The sidebar's settings search field, styled with the panel's translucent fill and rim.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                "preferences_search_placeholder".loco(),
                text: $searchQuery
            )
            .textFieldStyle(.plain)
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
        .font(.system(size: 13))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(PanelChrome.rim(colorScheme), lineWidth: 0.8)
        )
    }

    private var sidebarSelection: Binding<SidebarSelection?> {
        Binding(
            get: { selection },
            set: { newValue in
                if let newValue { selection = newValue }
            }
        )
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if isSearching {
            SettingsSearchResults(query: trimmedQuery) { entry in
                selection = .tab(entry.tab)
                searchQuery = ""
            }
        } else {
            switch selection {
            case .tab(let tab):
                paneContent(tab)
            case .about:
                AboutSupportView()
            }
        }
    }

    @MainActor
    @ViewBuilder
    private func paneContent(_ tab: PreferencesTab) -> some View {
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
}

#Preview {
    PreferencesShellV2()
        .frame(
            width: PreferencesWindowMetrics.defaultSize.width,
            height: PreferencesWindowMetrics.defaultSize.height
        )
}
