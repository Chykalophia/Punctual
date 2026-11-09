//
//  AlertsTab.swift
//  Punctual
//
//  The Alerts pane: notifications before a meeting starts and ends, auto-join,
//  and AppleScript hooks around meetings.
//
//  Derived from MeetingBar's notification and advanced preferences, originally:
//    Created by Andrii Leitsius on 13.01.2021.
//    Copyright © 2021 Andrii Leitsius. All rights reserved.
//    Licensed under the Apache License, Version 2.0.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Defaults
import SwiftUI

struct AlertsTab: View {
    var body: some View {
        PreferencesGroupedForm {
            BeforeMeetingStartsSection()
            BeforeMeetingEndsSection()
            JoinForMeSection()
            MeetingScriptsSection()
            PreferencesResetSection(tab: .alerts)
        }
    }
}

// MARK: - Before a meeting starts

private struct BeforeMeetingStartsSection: View {
    @Default(.joinEventNotification) private var joinEventNotification
    @Default(.joinEventNotificationTime) private var joinEventNotificationTime
    @Default(.fullscreenNotification) private var fullscreenNotification
    @Default(.fullscreenNotificationTime) private var fullscreenNotificationTime
    @Default(.fullscreenNotificationsForEventsWithoutMeetingLink)
    private var fullscreenNotificationsForEventsWithoutMeetingLink

    var body: some View {
        Section(header: Text("preferences_alerts_before_start_title".loco())) {
            Toggle("preferences_alerts_notify_start_toggle".loco(), isOn: $joinEventNotification)

            HowEarlyPicker(selection: $joinEventNotificationTime)
                .disabled(!joinEventNotification)

            NotificationDeliveryRow()

            Toggle("preferences_alerts_fullscreen_toggle".loco(), isOn: $fullscreenNotification)

            HowEarlyPicker(selection: $fullscreenNotificationTime)
                .disabled(!fullscreenNotification)

            Toggle(
                "preferences_alerts_fullscreen_without_link_toggle".loco(),
                isOn: $fullscreenNotificationsForEventsWithoutMeetingLink
            )
            .disabled(!fullscreenNotification)
            .preferenceIndent()

            Text("preferences_alerts_fullscreen_without_link_help".loco())
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .preferenceIndent()
        }
    }
}

// MARK: - Before a meeting ends

private struct BeforeMeetingEndsSection: View {
    @Default(.endOfEventNotification) private var endOfEventNotification
    @Default(.endOfEventNotificationTime) private var endOfEventNotificationTime

    var body: some View {
        Section(header: Text("preferences_alerts_before_end_title".loco())) {
            Toggle("preferences_alerts_notify_end_toggle".loco(), isOn: $endOfEventNotification)

            Picker("preferences_alerts_how_early".loco(), selection: $endOfEventNotificationTime) {
                Text("general_when_event_ends".loco()).tag(TimeBeforeEventEnd.atEnd)
                Text("general_one_minute_before".loco()).tag(TimeBeforeEventEnd.minuteBefore)
                Text("general_three_minute_before".loco()).tag(TimeBeforeEventEnd.threeMinuteBefore)
                Text("general_five_minute_before".loco()).tag(TimeBeforeEventEnd.fiveMinuteBefore)
            }
            .fixedSize()
            .preferenceIndent()
            .disabled(!endOfEventNotification)
        }
    }
}

// MARK: - Joining for you

private struct JoinForMeSection: View {
    @Default(.automaticEventJoin) private var automaticEventJoin
    @Default(.automaticEventJoinTime) private var automaticEventJoinTime

    private let navigation = PreferencesNavigation.shared

    var body: some View {
        Section(header: Text("preferences_alerts_automation_title".loco())) {
            Toggle("preferences_alerts_auto_join_toggle".loco(), isOn: $automaticEventJoin)

            HowEarlyPicker(selection: $automaticEventJoinTime)
                .disabled(!automaticEventJoin)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("preferences_alerts_auto_join_help".loco())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("preferences_alerts_auto_join_jump".loco()) {
                    navigation.go(to: .joining)
                }
                .controlSize(.small)
            }
            .preferenceIndent()
        }
    }
}

// MARK: - Run a script around meetings

private struct MeetingScriptsSection: View {
    @EnvironmentObject private var calendarSync: CalendarSync

    @Default(.runEventStartScript) private var runEventStartScript
    @Default(.eventStartScriptLocation) private var eventStartScriptLocation
    @Default(.eventStartScript) private var eventStartScript
    @Default(.eventStartScriptTime) private var eventStartScriptTime

    @Default(.runJoinEventScript) private var runJoinEventScript
    @Default(.joinEventScriptLocation) private var joinEventScriptLocation
    @Default(.joinEventScript) private var joinEventScript

    @State private var showingStartScriptEditor = false
    @State private var showingJoinScriptEditor = false

    var body: some View {
        Section {
            PreferencesDisclosure(
                id: "alerts.scripts",
                titleKey: "preferences_alerts_scripts_title"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    startScriptRows
                    Divider()
                    joinScriptRows
                }
                .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showingStartScriptEditor) {
            EditScriptModal(
                script: $eventStartScript,
                scriptLocation: $eventStartScriptLocation,
                scriptName: "eventStartScript.scpt"
            )
        }
        .sheet(isPresented: $showingJoinScriptEditor) {
            EditScriptModal(
                script: $joinEventScript,
                scriptLocation: $joinEventScriptLocation,
                scriptName: "joinEventScript.scpt"
            )
        }
    }

    @ViewBuilder
    private var startScriptRows: some View {
        Toggle("preferences_alerts_script_start_toggle".loco(), isOn: $runEventStartScript)

        HStack {
            HowEarlyPicker(selection: $eventStartScriptTime)
                .disabled(!runEventStartScript)

            Spacer()

            // Not disabled with the hook off: they act on the script file, which must exist before enabling.
            Button("preferences_alerts_script_test".loco()) {
                runAppleScriptForNextEvent(events: calendarSync.events)
            }
            Button("preferences_alerts_script_edit_start".loco()) {
                showingStartScriptEditor = true
            }
        }

        if runEventStartScript, eventStartScriptLocation == nil {
            scriptMissingWarning
        }

        scriptLinkOnlyHelp
    }

    @ViewBuilder
    private var joinScriptRows: some View {
        Toggle("preferences_alerts_script_join_toggle".loco(), isOn: $runJoinEventScript)

        HStack {
            Spacer()
            Button("preferences_alerts_script_edit_join".loco()) {
                showingJoinScriptEditor = true
            }
        }

        if runJoinEventScript, joinEventScriptLocation == nil {
            scriptMissingWarning
        }

        scriptLinkOnlyHelp
    }

    /// Warning for a hook that is on with no saved script; the scheduler skips it.
    private var scriptMissingWarning: some View {
        PreferenceCallout(
            systemImage: "exclamationmark.triangle.fill",
            message: "preferences_alerts_script_missing_warning".loco()
        )
        .preferenceIndent()
    }

    /// Caption shown, indented, under each hook.
    private var scriptLinkOnlyHelp: some View {
        Text("preferences_alerts_script_link_only_help".loco())
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .preferenceIndent()
    }
}

// MARK: - Shared rows

/// The labelled "How early" timing picker shared by the alert rows.
private struct HowEarlyPicker: View {
    @Binding var selection: TimeBeforeEvent

    var body: some View {
        Picker("preferences_alerts_how_early".loco(), selection: $selection) {
            Text("general_when_event_starts".loco()).tag(TimeBeforeEvent.atStart)
            Text("general_one_minute_before".loco()).tag(TimeBeforeEvent.minuteBefore)
            Text("general_three_minute_before".loco()).tag(TimeBeforeEvent.threeMinuteBefore)
            Text("general_five_minute_before".loco()).tag(TimeBeforeEvent.fiveMinuteBefore)
        }
        .fixedSize()
        .preferenceIndent()
    }
}

/// The app's notification delivery state with a button to fix it; renders nothing when delivery is fine.
private struct NotificationDeliveryRow: View {
    private let monitor = NotificationSettingsMonitor.shared

    var body: some View {
        let delivery = monitor.delivery

        Group {
            if let messageKey = delivery.messageKey {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(
                        systemName: delivery.isProblem
                            ? "exclamationmark.triangle.fill" : "info.circle"
                    )
                    .foregroundStyle(delivery.isProblem ? Color.orange : Color.secondary)

                    Text(messageKey.loco())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    if delivery.offersSettingsButton {
                        Button(NotificationDelivery.settingsButtonKey.loco()) {
                            if !NSWorkspace.shared.open(Links.notificationPreferences) {
                                NSWorkspace.shared.open(Links.systemSettings)
                            }
                        }
                        .controlSize(.small)
                    }
                }
                .preferenceIndent()
            }
        }
        .task { await monitor.refresh() }
        // Re-read on activation: the user may have changed it in System Settings.
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            Task { await monitor.refresh() }
        }
    }
}

// MARK: - The script editor

struct EditScriptModal: View {
    @Environment(\.presentationMode) var presentationMode

    @Binding var script: String
    @Binding var scriptLocation: URL?
    var scriptName: String

    @State var editedScript: String = ""

    @State private var showingAlert = false

    var body: some View {
        VStack {
            Spacer()
            Text("preferences_alerts_script_editor_title".loco())
            Spacer()
            NSScrollableTextViewWrapper(text: $editedScript).padding(.leading, 19)
            Spacer()
            HStack {
                Button(action: cancel) {
                    Text("general_cancel".loco())
                }
                Spacer()
                Button(action: saveScript) {
                    Text("general_save".loco())
                }.disabled(self.editedScript == self.script)
            }
            Spacer()
        }.padding()
            .frame(width: 500, height: 500)
            // Seeded here, not as the Defaults default, to avoid a localized string fixed at static init.
            .onAppear {
                self.editedScript = self.script.isEmpty
                    ? "preferences_alerts_script_placeholder".loco()
                    : self.script
            }
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("preferences_alerts_script_wrong_location_title".loco()),
                    message: Text("preferences_alerts_script_wrong_location_message".loco()),
                    dismissButton: .default(
                        Text("preferences_alerts_script_wrong_location_button".loco()))
                )
            }
    }

    func saveScript() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedContentTypes = [.appleScript]
        openPanel.allowsOtherFileTypes = false
        openPanel.prompt = "preferences_alerts_script_save_button".loco()
        openPanel.message = "preferences_alerts_script_wrong_location_message".loco()
        let scriptPath = try? FileManager.default.url(
            for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil,
            create: true)
        openPanel.directoryURL = scriptPath
        openPanel.begin { response in
            if response == .OK {
                if openPanel.url != scriptPath {
                    showingAlert = true
                    return
                }
                scriptLocation = openPanel.url
                if let filepath = openPanel.url?.appendingPathComponent(scriptName) {
                    do {
                        try editedScript.write(
                            to: filepath, atomically: true, encoding: String.Encoding.utf8)
                        script = editedScript
                        presentationMode.wrappedValue.dismiss()
                    } catch {}
                }
            }
            openPanel.close()
        }
    }

    func cancel() {
        presentationMode.wrappedValue.dismiss()
    }
}

struct NSScrollableTextViewWrapper: NSViewRepresentable {
    typealias NSViewType = NSScrollView
    var isEditable = true
    var textSize: CGFloat = 12

    @Binding var text: String

    var didEndEditing: (() -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as? NSTextView
        textView?.font = NSFont.systemFont(ofSize: textSize)
        textView?.isEditable = isEditable
        textView?.isSelectable = true
        textView?.isAutomaticQuoteSubstitutionEnabled = false
        textView?.delegate = context.coordinator

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context _: Context) {
        let textView = nsView.documentView as? NSTextView
        guard textView?.string != text else {
            return
        }

        textView?.string = text
        textView?.display()  // force update UI to re-draw the string
        textView?.scrollRangeToVisible(NSRange(location: text.count, length: 0))
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var view: NSScrollableTextViewWrapper

        init(_ view: NSScrollableTextViewWrapper) {
            self.view = view
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            view.text = textView.string
        }

        func textDidEndEditing(_: Notification) {
            view.didEndEditing?()
        }
    }
}
