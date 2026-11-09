//
//  CalendarsTab.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 13.01.2021.
//  Copyright © 2021 Andrii Leitsius. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
//  Calendars pane: calendar sources, sync status, calendar selection, the
//  Reminders permission and troubleshooting. Has no reset action: it stores
//  no settings, only a macOS permission and the calendar selection.
//

import Defaults
import SwiftUI

struct CalendarsTab: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        let presentation = PreferencesCalendarPresentation.make(
            from: appModel.state,
            authorizationStatus: PermissionReporter.calendarAuthorizationStatus()
        )

        PreferencesGroupedForm {
            CalendarSourceSection(presentation: presentation)
            CalendarSyncStatusSection(presentation: presentation)
            CalendarSelectionSection(presentation: presentation)
            RemindersPermissionSection()
            CalendarTroubleshootingSection(presentation: presentation)
        }
    }
}

// MARK: - Calendar source

/// One toggle per calendar source; sources can be connected together.
///
/// Renders only when more than one source is available.
private struct CalendarSourceSection: View {
    @EnvironmentObject var appModel: AppModel
    let presentation: PreferencesCalendarPresentation

    var body: some View {
        let sources = CalendarSourcePresentation.all
        if sources.count > 1 {
            Section {
                ForEach(sources) { source in
                    CalendarSourceToggle(
                        source: source,
                        isConnected: presentation.connectedProviders.contains(source.provider),
                        canDisconnect: presentation.connectedProviders.count > 1,
                        failure: presentation.degradedSources
                            .first { $0.provider == source.provider }
                    )
                }

                Text("preferences_calendars_source_help".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One source: a toggle, its description, and, when it is failing, the reason and a reconnect action.
private struct CalendarSourceToggle: View {
    @EnvironmentObject var appModel: AppModel
    let source: CalendarSourcePresentation
    let isConnected: Bool
    let canDisconnect: Bool
    let failure: CalendarSourceFailure?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(source.titleKey.loco(), isOn: connectionBinding)
                .disabled(appModel.state.providerChangeInProgress || !canToggle)

            Text(source.descriptionKey.loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Shown regardless of the toggle, which stays disabled until a client exists.
            if source.provider == .googleCalendar {
                GoogleOAuthClientSection(hasClient: hasGoogleClient)
            }

            if let failure {
                HStack(spacing: 6) {
                    Label(failure.errorDescription, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)

                    if failure.authRequired {
                        Button("preferences_status_reconnect".loco()) {
                            appModel.send(.changeProvider(source.provider, signOut: true))
                        }
                        .controlSize(.small)
                        .disabled(appModel.state.providerChangeInProgress)
                    }
                }
            }
        }
    }

    /// False for the last connected source, and for Google when no OAuth client is configured.
    private var canToggle: Bool {
        guard !isConnected else { return canDisconnect }
        return source.provider != .googleCalendar || hasGoogleClient
    }

    private var hasGoogleClient: Bool { GoogleOAuthConfig.effectiveClient != nil }

    /// On: signs in and adds the source. Off: disconnects but keeps its credentials.
    private var connectionBinding: Binding<Bool> {
        Binding(
            get: { isConnected },
            set: { shouldConnect in
                guard shouldConnect != isConnected else { return }
                if shouldConnect {
                    appModel.send(.changeProvider(source.provider, signOut: false))
                } else {
                    appModel.send(.disconnectProvider(source.provider))
                }
            }
        )
    }
}

/// An account header with a badge naming the source its calendars came from.
///
/// The same Google account can appear once via macOS Calendar and once via the direct provider.
private struct CalendarAccountHeader: View {
    let group: CalendarAccountGroup

    var body: some View {
        HStack(spacing: 6) {
            Text(group.titleKey?.loco() ?? group.title)

            Text(group.providerTitleKey.loco())
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(Color.secondary.opacity(0.15))
                )
                .accessibilityLabel(
                    "preferences_calendars_account_source".loco(group.providerTitleKey.loco())
                )
        }
    }
}

/// Editor for a user-supplied Google OAuth client (id and secret).
///
/// Lets users run on their own Google Cloud project's quota and consent screen,
/// and is the only way to use Google in a build that ships no client.
private struct GoogleOAuthClientSection: View {
    let hasClient: Bool

    @Default(.googleUseUserOAuthClient) private var useOwnClient
    @State private var clientID: String = GoogleUserOAuthClientStore.clientID
    @State private var clientSecret: String = GoogleUserOAuthClientStore.clientSecret

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("preferences_calendars_google_own_client".loco(), isOn: ownClientBinding)

            if useOwnClient {
                TextField(
                    "preferences_calendars_google_client_id".loco(),
                    text: $clientID
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: clientID) { _, newValue in
                    GoogleUserOAuthClientStore.clientID = newValue
                }

                SecureField(
                    "preferences_calendars_google_client_secret".loco(),
                    text: $clientSecret
                )
                .textFieldStyle(.roundedBorder)
                .onChange(of: clientSecret) { _, newValue in
                    GoogleUserOAuthClientStore.clientSecret = newValue
                }

                if !clientID.isEmpty, !GoogleOAuthClientResolver.isValidClientID(clientID) {
                    Label(
                        "preferences_calendars_google_client_id_invalid".loco(),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                Text("preferences_calendars_google_own_client_help".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !hasClient {
                Label(
                    "preferences_calendars_google_no_client".loco(),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 20)
    }

    /// Turning this off also clears the stored client id and secret from the Keychain.
    private var ownClientBinding: Binding<Bool> {
        Binding(
            get: { useOwnClient },
            set: { enabled in
                useOwnClient = enabled
                if !enabled {
                    GoogleUserOAuthClientStore.clear()
                    clientID = ""
                    clientSecret = ""
                }
            }
        )
    }
}

// MARK: - Sync status

/// Sync status line with the last successful refresh time and the refresh actions.
private struct CalendarSyncStatusSection: View {
    @EnvironmentObject var appModel: AppModel
    let presentation: PreferencesCalendarPresentation

    var body: some View {
        Section {
            HStack(spacing: 6) {
                Label(
                    presentation.statusTextKey.loco(),
                    systemImage: statusSystemImage(presentation.statusTone)
                )
                .foregroundStyle(statusColor(presentation.statusTone))
                .font(.subheadline.weight(.medium))

                if let lastSuccess = appModel.state.providerHealth.lastSuccessfulRefresh {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(
                        "preferences_calendars_status_refreshed".loco(
                            lastSuccess.formatted(.relative(presentation: .named))
                        )
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }

                Spacer()

                if presentation.canRequestAccess {
                    // Goes through `.changeProvider` so sign-in triggers the EventKit prompt and TCC registration.
                    Button("preferences_calendars_grant_access".loco()) {
                        appModel.send(.changeProvider(presentation.activeProvider, signOut: false))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appModel.state.providerChangeInProgress)
                }

                // `.forceCalendarSync`, not `.refreshCalendars`: asks macOS to sync, not just re-fetch.
                Button("preferences_calendars_refresh_now".loco()) {
                    appModel.send(.forceCalendarSync)
                }
                .disabled(appModel.state.providerChangeInProgress)
            }
        }
    }
}

// MARK: - Calendar selection

/// "Calendars to show": per-account groups with search, All/None and a selected count.
private struct CalendarSelectionSection: View {
    @EnvironmentObject var appModel: AppModel
    let presentation: PreferencesCalendarPresentation

    @State private var query = ""

    private var items: [CalendarPickerItem] {
        appModel.state.calendars.map {
            CalendarPickerItem(
                id: $0.id,
                title: $0.title,
                source: $0.source,
                email: $0.email,
                provider: $0.provider.sourceKind
            )
        }
    }

    private var groups: [CalendarAccountGroup] {
        CalendarListPresentation.groups(for: items, query: query)
    }

    var body: some View {
        Section(header: Text("preferences_calendars_list_title".loco())) {
            Text("preferences_calendars_list_help".loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if appModel.state.calendars.isEmpty {
                CalendarSelectionEmptyState(presentation: presentation)
            } else {
                HStack(spacing: 8) {
                    TextField(
                        "preferences_calendars_search_placeholder".loco(),
                        text: $query
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)

                    Text(
                        "preferences_calendars_selected_count".loco(
                            presentation.selectedCalendarCount,
                            presentation.availableCalendarCount
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                    Button("preferences_calendars_select_all".loco()) {
                        setSelection(true)
                    }
                    .controlSize(.small)
                    Button("preferences_calendars_select_none".loco()) {
                        setSelection(false)
                    }
                    .controlSize(.small)
                }
            }
        }

        ForEach(groups) { group in
            Section(header: CalendarAccountHeader(group: group)) {
                ForEach(group.rows) { row in
                    if let calendar = calendar(for: row.id) {
                        CalendarRow(calendar: calendar, subtitle: row.subtitle)
                    }
                }
            }
        }
    }

    private func calendar(for id: String) -> MBCalendar? {
        appModel.state.calendars.first { $0.id == id }
    }

    /// Selects or deselects every calendar currently visible under the search filter.
    private func setSelection(_ selected: Bool) {
        for id in CalendarListPresentation.visibleIDs(in: groups) {
            appModel.toggleCalendarSelection(
                id: id, selected: selected, provider: calendar(for: id)?.provider)
        }
    }
}

/// Empty-list message with the action that resolves it (grant access, open Privacy settings, or refresh).
private struct CalendarSelectionEmptyState: View {
    @EnvironmentObject var appModel: AppModel
    let presentation: PreferencesCalendarPresentation

    var body: some View {
        VStack(spacing: 12) {
            Text(presentation.emptyStateTextKey.loco())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if presentation.canRequestAccess {
                Button("preferences_calendars_grant_access".loco()) {
                    appModel.send(.changeProvider(presentation.activeProvider, signOut: false))
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.state.providerChangeInProgress)
            } else if presentation.canOpenCalendarSettings {
                Button("preferences_calendars_open_privacy".loco()) {
                    NSWorkspace.shared.open(Links.calendarPreferences)
                }
            } else {
                Button("preferences_calendars_refresh_now".loco()) {
                    appModel.send(.forceCalendarSync)
                }
                .disabled(appModel.state.providerChangeInProgress)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Reminders permission

/// Reminders access: an Allow button while undetermined, then a status row or a link to System Settings.
///
/// Deliberately not a toggle: macOS permissions are request-once and revocable only
/// in System Settings, so a switch would be disabled in both settled states.
private struct RemindersPermissionSection: View {
    @State private var isGranted = false
    @State private var isDenied = false
    /// True from the click until macOS answers the access request.
    @State private var isRequesting = false

    var body: some View {
        Section {
            LabeledContent("preferences_calendars_reminders_label".loco()) {
                statusControl
            }

            explanation
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .preferenceIndent()
        }
        .animation(.default, value: isGranted)
        .animation(.default, value: isDenied)
        .animation(.default, value: isRequesting)
        .onAppear(perform: refresh)
        // Re-read on activation: the user may have changed it in System Settings.
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification
            )
        ) { _ in
            refresh()
        }
    }

    @ViewBuilder
    private var statusControl: some View {
        if isRequesting {
            ProgressView().controlSize(.small)
        } else if isGranted {
            Label(
                "preferences_calendars_reminders_allowed".loco(),
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
            .labelStyle(.titleAndIcon)
        } else if isDenied {
            // macOS will not prompt again once denied.
            Button("preferences_calendars_reminders_open_settings".loco()) {
                NSWorkspace.shared.open(Links.remindersPreferences)
            }
        } else {
            Button("preferences_calendars_reminders_allow".loco(), action: requestAccess)
        }
    }

    @ViewBuilder
    private var explanation: some View {
        if isRequesting {
            Text("preferences_calendars_reminders_requesting".loco())
        } else if isGranted {
            VStack(alignment: .leading, spacing: 6) {
                Text("preferences_calendars_reminders_granted".loco())
                    .fixedSize(horizontal: false, vertical: true)

                // Hiding reminders is a Dropdown pane setting, not a permission.
                Button("preferences_calendars_reminders_where_to_hide".loco()) {
                    PreferencesNavigation.shared.go(to: .dropdown)
                }
                .controlSize(.small)
            }
        } else if isDenied {
            Text("preferences_calendars_reminders_denied".loco())
        } else {
            Text("preferences_calendars_reminders_help".loco())
        }
    }

    private func requestAccess() {
        guard !isRequesting, !isGranted, !isDenied else { return }
        isRequesting = true
        Task {
            _ = await RemindersStore.shared.requestAccess()
            await MainActor.run {
                isRequesting = false
                refresh()
            }
        }
    }

    private func refresh() {
        let status = RemindersStore.shared.authorizationStatus
        isGranted = RemindersStore.isGranted(status)
        isDenied = RemindersStore.isDenied(status)
        PunctualLogger.calendar.debug(
            "Reminders authorization: raw=\(status.rawValue, privacy: .public) granted=\(isGranted, privacy: .public) denied=\(isDenied, privacy: .public)"
        )
    }
}

// MARK: - Troubleshooting

/// "Calendar isn't updating?" disclosure: explanation, last synced change, raw error and recovery shortcuts.
///
/// Recovery actions show, and the disclosure opens itself, only in an error state;
/// `canReauthenticateAccount` alone is true for every EventKit install.
private struct CalendarTroubleshootingSection: View {
    @EnvironmentObject var appModel: AppModel
    let presentation: PreferencesCalendarPresentation

    private var hasError: Bool {
        switch presentation.connectionState {
        case .authRequired, .permissionRequired, .error, .stale: true
        case .initializing, .connected: false
        }
    }

    var body: some View {
        Section {
            PreferencesDisclosure(
                id: "calendars.troubleshooting",
                titleKey: "preferences_calendars_troubleshoot_title",
                opensAutomatically: hasError
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("preferences_calendars_troubleshoot_notice".loco())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Shown, not judged: an hours-old value means macOS stopped syncing.
                    if let lastSyncedChange = presentation.lastSyncedChange {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                "preferences_calendars_last_change".loco(
                                    lastSyncedChange.formatted(.relative(presentation: .named))
                                )
                            )
                            Text("preferences_calendars_last_change_help".loco())
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if let error = appModel.state.providerHealth.lastErrorDescription {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("preferences_calendars_error_intro".loco())
                            Text(error)
                                .foregroundStyle(.red)
                                .textSelection(.enabled)
                                .lineLimit(3)
                        }
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    if hasError {
                        HStack {
                            Button("preferences_calendars_open_privacy".loco()) {
                                NSWorkspace.shared.open(Links.calendarPreferences)
                            }
                            // Expired account credentials make macOS Calendar serve stale data silently.
                            if presentation.canReauthenticateAccount {
                                Button("preferences_calendars_open_internet_accounts".loco()) {
                                    if !NSWorkspace.shared.open(Links.internetAccountsPreferences) {
                                        NSWorkspace.shared.open(Links.systemSettings)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Shared pieces

private func statusSystemImage(_ tone: PreferencesStatusTone) -> String {
    switch tone {
    case .neutral: "circle"
    case .success: "checkmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .error: "xmark.circle.fill"
    }
}

private func statusColor(_ tone: PreferencesStatusTone) -> Color {
    switch tone {
    case .neutral: .secondary
    case .success: .green
    case .warning: .orange
    case .error: .red
    }
}

/// Plain source-grouped calendar list used by the onboarding calendar screen.
struct CalendarSectionsView: View {
    let calendars: [MBCalendar]

    private var grouped: [String: [MBCalendar]] {
        Dictionary(grouping: calendars, by: \.source)
    }

    private var sources: [String] {
        grouped.keys.sorted()
    }

    var body: some View {
        ForEach(sources, id: \.self) { source in
            Section(header: Text(source)) {
                ForEach(grouped[source]!, id: \.id) { cal in
                    CalendarRow(calendar: cal)
                }
            }
        }
    }
}

struct CalendarRow: View {
    let calendar: MBCalendar
    /// Account address shown under the title; `nil` unless another calendar shares this name.
    var subtitle: String?
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { appModel.state.selectedCalendarIDs.contains(calendar.id) },
                set: {
                    appModel.toggleCalendarSelection(
                        id: calendar.id, selected: $0, provider: calendar.provider)
                }
            )
        ) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(calendar.color))
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title)
                        .lineLimit(1)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        CalendarSectionsView(calendars: [
            MBCalendar(
                title: "Calendar #1", id: "1", source: "Source #1", email: nil, color: .brown)
        ])

        CalendarSectionsView(calendars: [
            MBCalendar(title: "Calendar #2", id: "2", source: "Source #2", email: nil, color: .blue)
        ])
    }.listStyle(.sidebar)
        .frame(width: 300, height: 200)
}
