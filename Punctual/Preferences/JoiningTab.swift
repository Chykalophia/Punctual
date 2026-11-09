//
//  JoiningTab.swift
//  Punctual
//
//  The Joining pane: how meeting links open, where new meetings are created,
//  saved links, and custom meeting-link patterns.
//
//  Derived from MeetingBar's MeetingsTab.swift, originally:
//    Created by Andrii Leitsius on 13.01.2021.
//    Copyright © 2021 Andrii Leitsius. All rights reserved.
//    Licensed under the Apache License, Version 2.0.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Defaults
import SwiftUI

struct JoiningTab: View {
    var body: some View {
        PreferencesGroupedForm {
            MeetingLinkOpeningSection()
            CreateMeetingSection()
            SavedLinksSection()
            MeetingLinkPatternsSection()
            PreferencesResetSection(tab: .joining)
        }
    }
}

// MARK: - Opening meeting links

private struct MeetingLinkOpeningSection: View {
    @Default(.defaultBrowser) private var defaultBrowser
    @Default(.browsers) private var allBrowsers

    @State private var showBrowserConfiguration = false

    private var defaultBrowserOptions: [Browser] {
        BrowserPickerOptions.make(configured: allBrowsers, selected: defaultBrowser)
    }

    var body: some View {
        Section {
            Picker(
                "preferences_joining_default_browser_title".loco(),
                selection: $defaultBrowser
            ) {
                ForEach(defaultBrowserOptions, id: \.self) { (browser: Browser) in
                    Text(browser.name).tag(browser)
                }
            }

            Text("preferences_joining_default_browser_help".loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            PreferencesDisclosure(
                id: "joining.overrides",
                titleKey: "preferences_joining_overrides_title"
            ) {
                Text("preferences_joining_overrides_help".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)

                ForEach(
                    MeetingProvider.all.filter { !$0.openingModes.isEmpty }, id: \.id
                ) { provider in
                    MeetingProviderOpeningPicker(provider: provider)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button("preferences_joining_configure_browsers_button".loco()) {
                    showBrowserConfiguration.toggle()
                }
                .sheet(isPresented: $showBrowserConfiguration) {
                    BrowserConfigView()
                }
                Text("preferences_joining_configure_browsers_help".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One service's override picker, with opening modes (apps) and browsers in two labelled groups.
struct MeetingProviderOpeningPicker: View {
    let provider: MeetingProvider

    @Default(.providerBrowsers) private var providerBrowsers
    @Default(.providerOpeningModes) private var providerOpeningModes
    @Default(.browsers) private var allBrowsers

    private var selectedValue: MeetingProviderOpeningSelection {
        MeetingProviderOpeningSelectionPolicy.selected(
            provider: provider,
            providerBrowsers: providerBrowsers,
            providerOpeningModes: providerOpeningModes
        )
    }

    private var selection: Binding<MeetingProviderOpeningSelection> {
        Binding(
            get: { selectedValue },
            set: { newSelection in
                let updated = MeetingProviderOpeningSelectionPolicy.updating(
                    provider: provider,
                    selection: newSelection,
                    providerBrowsers: providerBrowsers,
                    providerOpeningModes: providerOpeningModes
                )
                providerBrowsers = updated.providerBrowsers
                providerOpeningModes = updated.providerOpeningModes
            }
        )
    }

    private var browserOptions: [Browser] {
        let selectedBrowser: Browser
        switch selectedValue {
        case .browser(let browser):
            selectedBrowser = browser
        case .mode:
            selectedBrowser = systemDefaultBrowser
        }
        return BrowserPickerOptions.make(
            configured: allBrowsers,
            selected: selectedBrowser
        )
    }

    var body: some View {
        Picker(
            selection: selection,
            label: Text("preferences_joining_service_title".loco(provider.displayName))
        ) {
            Section(header: Text("preferences_joining_overrides_group_apps".loco())) {
                ForEach(provider.openingModes, id: \.self) { mode in
                    Text(mode.titleKey.loco()).tag(
                        MeetingProviderOpeningSelection.mode(mode)
                    )
                }
            }
            Section(header: Text("preferences_joining_overrides_group_browsers".loco())) {
                ForEach(browserOptions, id: \.self) { browser in
                    Text(browser.name).tag(MeetingProviderOpeningSelection.browser(browser))
                }
            }
        }

        if case let .mode(mode) = selectedValue,
           let helpKey = mode.helpKey {
            Text(helpKey.loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .preferenceIndent()
        }
    }
}

// MARK: - Creating meetings

private struct CreateMeetingSection: View {
    @Default(.createMeetingService) private var createMeetingService
    @Default(.createMeetingServiceUrl) private var createMeetingServiceUrl
    @Default(.browserForCreateMeeting) private var browserForCreateMeeting
    @Default(.browsers) private var allBrowsers

    private var createMeetingBrowserOptions: [Browser] {
        BrowserPickerOptions.make(configured: allBrowsers, selected: browserForCreateMeeting)
    }

    var body: some View {
        Section(header: Text("preferences_joining_create_title".loco())) {
            HStack {
                Text("preferences_joining_create_service_title".loco())
                Spacer()
                CreateMeetingServicePicker()
                    .fixedSize()
            }

            if createMeetingService == CreateMeetingServices.url {
                HStack {
                    Text("preferences_joining_create_url_title".loco())
                    TextField(
                        "preferences_services_create_meeting_custom_url_placeholder".loco(),
                        text: $createMeetingServiceUrl
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                Text("preferences_joining_create_url_tip".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Picker(
                "preferences_joining_create_browser_title".loco(),
                selection: $browserForCreateMeeting
            ) {
                ForEach(createMeetingBrowserOptions, id: \.self) { (browser: Browser) in
                    Text(browser.name).tag(browser)
                }
            }
        }
    }
}

struct CreateMeetingServicePicker: View {
    @Default(.createMeetingService) var createMeetingService

    var body: some View {
        Picker(selection: $createMeetingService, label: EmptyView()) {
            Text(CreateMeetingServices.meet.localizedValue).tag(CreateMeetingServices.meet)
            Text(CreateMeetingServices.zoom.localizedValue).tag(CreateMeetingServices.zoom)
            Text(CreateMeetingServices.teams.localizedValue).tag(CreateMeetingServices.teams)
            Text(CreateMeetingServices.jam.localizedValue).tag(CreateMeetingServices.jam)
            Text(CreateMeetingServices.coscreen.localizedValue).tag(CreateMeetingServices.coscreen)
            Text(CreateMeetingServices.gcalendar.localizedValue).tag(
                CreateMeetingServices.gcalendar)
            Text(CreateMeetingServices.outlook_live.localizedValue).tag(
                CreateMeetingServices.outlook_live)
            Text(CreateMeetingServices.outlook_office365.localizedValue).tag(
                CreateMeetingServices.outlook_office365)
            Text(CreateMeetingServices.url.localizedValue).tag(CreateMeetingServices.url)
        }.labelsHidden()
    }
}

// MARK: - My saved links

/// The user's saved meeting links (`bookmarks`), shown as name, service and address columns.
private struct SavedLinksSection: View {
    @Default(.bookmarks) private var bookmarks

    @State private var showingAddModal = false
    @State private var showingDeleteAlert = false
    @State private var pendingDeletion: Bookmark?

    var body: some View {
        Section(header: Text("preferences_joining_links_title".loco())) {
            Text("preferences_joining_links_help".loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if bookmarks.isEmpty {
                Text("preferences_joining_links_empty".loco())
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(bookmarks.enumerated()), id: \.element) { index, bookmark in
                SavedLinkRow(
                    bookmark: bookmark,
                    canMoveUp: index > 0,
                    canMoveDown: index < bookmarks.count - 1,
                    moveUp: { move(from: index, to: index - 1) },
                    moveDown: { move(from: index, to: index + 1) },
                    delete: {
                        pendingDeletion = bookmark
                        showingDeleteAlert = true
                    }
                )
            }

            Button("preferences_joining_links_add_button".loco()) {
                showingAddModal.toggle()
            }
            .sheet(isPresented: $showingAddModal) {
                AddSavedLinkModal()
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("preferences_joining_links_delete_title".loco()),
                message: Text(
                    "preferences_joining_links_delete_message".loco(
                        pendingDeletion?.name ?? ""
                    )
                ),
                primaryButton: .destructive(Text("general_delete".loco())) {
                    if let pendingDeletion {
                        bookmarks.removeAll { $0.url == pendingDeletion.url }
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    private func move(from source: Int, to destination: Int) {
        guard bookmarks.indices.contains(source), bookmarks.indices.contains(destination) else {
            return
        }
        var updated = bookmarks
        updated.swapAt(source, destination)
        bookmarks = updated
    }
}

private struct SavedLinkRow: View {
    let bookmark: Bookmark
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void
    let delete: () -> Void

    private var serviceName: String {
        MeetingServices(rawValue: bookmark.service)?.localizedValue ?? bookmark.service
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(bookmark.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 140, alignment: .leading)

            Text(serviceName)
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)

            Text(bookmark.url.absoluteString)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Buttons, not a drag handle: `.onMove` is inert inside a `Form`.
            Button(action: moveUp) {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveUp)
            .help("preferences_joining_links_move_up".loco())

            Button(action: moveDown) {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canMoveDown)
            .help("preferences_joining_links_move_down".loco())

            Button(action: delete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("general_delete".loco())
        }
    }
}

struct AddSavedLinkModal: View {
    @Environment(\.presentationMode) var presentationMode

    @Default(.bookmarks) var bookmarks

    @State private var showingAlert = false
    @State private var errorMessage = ""

    @State var name: String = ""
    @State var url: String = ""
    @State var service = MeetingServices.meet

    var body: some View {
        VStack {
            HStack {
                Text("preferences_joining_links_new_title".loco()).font(.headline)
            }
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 15) {
                    Text("preferences_joining_links_new_name".loco())
                    Text("preferences_joining_links_new_link".loco())
                    Text("preferences_joining_links_new_service".loco())
                }
                VStack(alignment: .leading, spacing: 10) {
                    TextField("", text: $name)
                    TextField("", text: $url)
                    Picker(selection: $service, label: Text("")) {
                        Text(MeetingServices.teams.localizedValue).tag(MeetingServices.teams)
                        Text(MeetingServices.zoom.localizedValue).tag(MeetingServices.zoom)
                        Text(MeetingServices.meet.localizedValue).tag(MeetingServices.meet)
                        Text(MeetingServices.facetime.localizedValue).tag(MeetingServices.facetime)
                        Text(MeetingServices.facetimeaudio.localizedValue).tag(
                            MeetingServices.facetimeaudio)
                        Text(MeetingServices.phone.localizedValue).tag(MeetingServices.phone)
                        Text(MeetingServices.other.localizedValue).tag(MeetingServices.other)
                    }.labelsHidden()
                }
            }
            Spacer()
            HStack {
                Button("general_cancel".loco()) {
                    presentationMode.wrappedValue.dismiss()
                }
                Button("general_add".loco(), action: add)
                    .disabled(url.isEmpty || name.isEmpty)
            }
        }
        .frame(width: 500, height: 200)
        .padding()
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("preferences_joining_links_new_error_title".loco()),
                message: Text(errorMessage),
                dismissButton: .default(Text("general_ok".loco()))
            )
        }
    }

    private func add() {
        if let existing = bookmarks.first(where: { $0.url.absoluteString == url }) {
            errorMessage = "preferences_joining_links_new_duplicate".loco(existing.name, url)
            showingAlert = true
            return
        }
        guard let bookmarkURL = URL(string: url) else {
            errorMessage = "preferences_services_create_meeting_custom_url_placeholder".loco()
            showingAlert = true
            return
        }
        presentationMode.wrappedValue.dismiss()
        bookmarks.append(Bookmark(name: name, service: service.rawValue, url: bookmarkURL))
    }
}

// MARK: - Find meeting links in unusual formats

/// Editor and tester for `customRegexes`, the extra meeting-link patterns.
///
/// User-facing copy calls these "text patterns", never "regex".
private struct MeetingLinkPatternsSection: View {
    @Default(.customRegexes) private var customRegexes

    @State private var sampleText = ""
    @State private var testResult: String?
    @State private var didMatch = false

    var body: some View {
        Section {
            PreferencesDisclosure(
                id: "joining.link_patterns",
                titleKey: "preferences_joining_link_patterns_title"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("preferences_joining_link_patterns_help".loco())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextPatternList(patterns: $customRegexes)

                    Divider()

                    Text("preferences_joining_link_patterns_test_title".loco())
                        .font(.subheadline)
                    TextField(
                        "preferences_joining_link_patterns_test_placeholder".loco(),
                        text: $sampleText
                    )
                    .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(
                            "preferences_joining_link_patterns_test_button".loco(),
                            action: test
                        )
                        // Enabled with no patterns, to check whether the built-in detector already finds the link.
                        .disabled(sampleText.isEmpty)
                        if let testResult {
                            Text(testResult)
                                .foregroundStyle(didMatch ? Color.secondary : Color.red)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Runs the meeting-link detector with the sample text as notes, location and event URL.
    private func test() {
        let trimmed = sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = MeetingLinkDetector.allCandidates(
            location: sampleText,
            eventURL: URL(string: trimmed),
            notes: sampleText,
            calendarEmail: nil,
            currentUserEmail: nil,
            customRegexes: customRegexes
        )

        if let candidate = candidates.first {
            didMatch = true
            testResult = "preferences_joining_link_patterns_test_match".loco(
                candidate.url.absoluteString
            )
        } else {
            didMatch = false
            testResult = "preferences_joining_link_patterns_test_no_match".loco()
        }
    }
}

#Preview {
    JoiningTab().padding().frame(width: 700, height: 620)
}
