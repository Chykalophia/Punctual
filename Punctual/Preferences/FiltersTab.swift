//
//  FiltersTab.swift
//  Punctual
//
//  The Filters pane: decides which meetings appear on every surface (menu bar,
//  dropdown, calendar window). Filtering only; no per-surface styling belongs here.
//
//  The per-kind rows and the look-ahead / merge-duplicates controls derive from
//  MeetingBar's events preferences, originally:
//    Created by Andrii Leitsius on 13.01.2021.
//    Copyright © 2021 Andrii Leitsius. All rights reserved.
//  Licensed under the Apache License, Version 2.0.
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Defaults
import SwiftUI

struct FiltersTab: View {
    @Default(.showEventsForPeriod) private var showEventsForPeriod
    @Default(.deduplicateEvents) private var deduplicateEvents

    // Per-kind rows. `pastEventsAppereance` and `hideFinishedEventsInMenu` share one row; see `endedVisibility`.
    @Default(.allDayEvents) private var allDayEvents
    @Default(.nonAllDayEvents) private var nonAllDayEvents
    @Default(.personalEventsAppereance) private var personalEventsAppereance
    @Default(.showPendingEvents) private var showPendingEvents
    @Default(.showTentativeEvents) private var showTentativeEvents
    @Default(.declinedEventsAppereance) private var declinedEventsAppereance
    @Default(.pastEventsAppereance) private var pastEventsAppereance
    @Default(.hideFinishedEventsInMenu) private var hideFinishedEventsInMenu

    @Default(.ongoingEventVisibility) private var ongoingEventVisibility
    @Default(.filterEventRegexes) private var filterEventRegexes

    // Owned by `PreferencesDisclosure`; written here so the "Custom" chip can expand its rows.
    @Default(.preferencesExpandedDisclosures) private var expandedDisclosures

    /// Sample title for the pattern tester; never persisted.
    @State private var patternTestTitle = ""

    private static let customDisclosureID = "filters.custom"

    var body: some View {
        PreferencesGroupedForm {
            scopeBanner
            fetchSection
            presetSection
            customSection
            ongoingSection
            titlePatternSection
            PreferencesResetSection(tab: .filters)
        }
        .onAppear(perform: retireDeletedOptionValues)
    }

    // MARK: - Scope

    /// Non-dismissible banner stating that these filters apply to every surface.
    private var scopeBanner: some View {
        Section {
            PreferenceCallout(
                systemImage: "line.3.horizontal.decrease.circle.fill",
                message: "preferences_filters_scope_banner".loco(),
                tint: .accentColor
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - What gets loaded at all

    private var fetchSection: some View {
        Section {
            Picker(
                "preferences_filters_look_ahead_title".loco(),
                selection: $showEventsForPeriod
            ) {
                Text("preferences_filters_look_ahead_today".loco())
                    .tag(ShowEventsForPeriod.today)
                Text("preferences_filters_look_ahead_today_tomorrow".loco())
                    .tag(ShowEventsForPeriod.today_n_tomorrow)
                Text("preferences_filters_look_ahead_tomorrow_next".loco())
                    .tag(ShowEventsForPeriod.today_n_tomorrow_next)
                Text("preferences_filters_look_ahead_tomorrow_summary".loco())
                    .tag(ShowEventsForPeriod.today_n_tomorrow_summary)
            }
            .annotation("preferences_filters_look_ahead_help")

            Toggle("preferences_filters_dedup_toggle".loco(), isOn: $deduplicateEvents)
                .annotation("preferences_filters_dedup_help")
        }
    }

    // MARK: - Presets

    /// Preset chips. The selected chip is derived from the stored values via
    /// `FilterPreset.detect`, so "Custom" means "matches no preset".
    private var presetSection: some View {
        Section(header: Text("preferences_filters_preset_title".loco())) {
            Picker("", selection: presetSelection) {
                ForEach(FilterPreset.allCases, id: \.self) { preset in
                    Text(preset.titleKey.loco()).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    /// Selecting a named preset writes all its values; selecting "Custom" stores
    /// nothing and only expands the per-kind rows.
    private var presetSelection: Binding<FilterPreset> {
        Binding(
            get: { FilterPreset.detect(storedFilterValues) },
            set: { preset in
                guard preset != .custom else {
                    revealCustomRows()
                    return
                }
                apply(preset)
            }
        )
    }

    /// The stored filter values keyed by `FilterDefaultsKey`, as raw strings.
    private var storedFilterValues: [String: String] {
        [
            FilterDefaultsKey.allDay: allDayEvents.rawValue,
            FilterDefaultsKey.noLink: nonAllDayEvents.rawValue,
            FilterDefaultsKey.solo: personalEventsAppereance.rawValue,
            FilterDefaultsKey.pending: showPendingEvents.rawValue,
            FilterDefaultsKey.tentative: showTentativeEvents.rawValue,
            FilterDefaultsKey.declined: declinedEventsAppereance.rawValue,
            FilterDefaultsKey.ended: pastEventsAppereance.rawValue,
            FilterDefaultsKey.hideFinished: String(hideFinishedEventsInMenu)
        ]
    }

    private func apply(_ preset: FilterPreset) {
        let values = preset.values
        guard !values.isEmpty else { return }

        if let raw = values[FilterDefaultsKey.allDay],
           let value = AlldayEventsAppereance(rawValue: raw) {
            allDayEvents = value
        }
        if let raw = values[FilterDefaultsKey.noLink],
           let value = NonAlldayEventsAppereance(rawValue: raw) {
            nonAllDayEvents = value
        }
        if let raw = values[FilterDefaultsKey.solo],
           let value = PastEventsAppereance(rawValue: raw) {
            personalEventsAppereance = value
        }
        if let raw = values[FilterDefaultsKey.pending],
           let value = PendingEventsAppereance(rawValue: raw) {
            showPendingEvents = value
        }
        if let raw = values[FilterDefaultsKey.tentative],
           let value = TentativeEventsAppereance(rawValue: raw) {
            showTentativeEvents = value
        }
        if let raw = values[FilterDefaultsKey.declined],
           let value = DeclinedEventsAppereance(rawValue: raw) {
            declinedEventsAppereance = value
        }
        if let raw = values[FilterDefaultsKey.ended],
           let value = PastEventsAppereance(rawValue: raw) {
            pastEventsAppereance = value
        }
        if let raw = values[FilterDefaultsKey.hideFinished] {
            hideFinishedEventsInMenu = (raw == "true")
        }

        PunctualLogger.preferences.info(
            "Applied filter preset \(preset.rawValue, privacy: .public)"
        )
    }

    private func revealCustomRows() {
        guard !expandedDisclosures.contains(Self.customDisclosureID) else { return }
        expandedDisclosures.append(Self.customDisclosureID)
    }

    // MARK: - The seven rows

    /// The per-kind rows, each offering Show / Dim / Hide.
    ///
    /// Exceptions: all-day offers "only with a meeting link" instead of Dim, and
    /// declined offers "crossed out" (`.strikethrough`) instead of Show.
    private var customSection: some View {
        Section {
            PreferencesDisclosure(
                id: Self.customDisclosureID,
                titleKey: "preferences_filters_custom_title",
                subtitleKey: "preferences_filters_custom_subtitle"
            ) {
                Picker("preferences_filters_all_day_title".loco(), selection: $allDayEvents) {
                    Text("preferences_filters_value_show".loco())
                        .tag(AlldayEventsAppereance.show)
                    Text("preferences_filters_value_only_with_link".loco())
                        .tag(AlldayEventsAppereance.show_with_meeting_link_only)
                    Text("preferences_filters_value_hide".loco())
                        .tag(AlldayEventsAppereance.hide)
                }

                Picker("preferences_filters_no_link_title".loco(), selection: $nonAllDayEvents) {
                    Text("preferences_filters_value_show".loco())
                        .tag(NonAlldayEventsAppereance.show)
                    Text("preferences_filters_value_dim".loco())
                        .tag(NonAlldayEventsAppereance.show_inactive_without_meeting_link)
                    Text("preferences_filters_value_hide".loco())
                        .tag(NonAlldayEventsAppereance.hide_without_meeting_link)
                }

                Picker(
                    "preferences_filters_solo_title".loco(),
                    selection: $personalEventsAppereance
                ) {
                    Text("preferences_filters_value_show".loco())
                        .tag(PastEventsAppereance.show_active)
                    Text("preferences_filters_value_dim".loco())
                        .tag(PastEventsAppereance.show_inactive)
                    Text("preferences_filters_value_hide".loco())
                        .tag(PastEventsAppereance.hide)
                }

                Picker("preferences_filters_pending_title".loco(), selection: $showPendingEvents) {
                    Text("preferences_filters_value_show".loco())
                        .tag(PendingEventsAppereance.show)
                    Text("preferences_filters_value_dim".loco())
                        .tag(PendingEventsAppereance.show_inactive)
                    Text("preferences_filters_value_hide".loco())
                        .tag(PendingEventsAppereance.hide)
                }

                Picker(
                    "preferences_filters_tentative_title".loco(),
                    selection: $showTentativeEvents
                ) {
                    Text("preferences_filters_value_show".loco())
                        .tag(TentativeEventsAppereance.show)
                    Text("preferences_filters_value_dim".loco())
                        .tag(TentativeEventsAppereance.show_inactive)
                    Text("preferences_filters_value_hide".loco())
                        .tag(TentativeEventsAppereance.hide)
                }

                Picker(
                    "preferences_filters_declined_title".loco(),
                    selection: $declinedEventsAppereance
                ) {
                    Text("preferences_filters_value_show_crossed_out".loco())
                        .tag(DeclinedEventsAppereance.strikethrough)
                    Text("preferences_filters_value_dim".loco())
                        .tag(DeclinedEventsAppereance.show_inactive)
                    Text("preferences_filters_value_hide".loco())
                        .tag(DeclinedEventsAppereance.hide)
                }

                Picker("preferences_filters_ended_title".loco(), selection: endedVisibility) {
                    Text("preferences_filters_value_show".loco()).tag(FilterVisibility.show)
                    Text("preferences_filters_value_dim".loco()).tag(FilterVisibility.dim)
                    Text("preferences_filters_value_hide".loco()).tag(FilterVisibility.hide)
                }
                helpText("preferences_filters_ended_help")

                // Dim also excludes a meeting from menu bar next-meeting selection
                // (`hidesFromNextEvent` is true for `.hide` and `.show_inactive`).
                helpText("preferences_filters_menu_bar_note")
            }
        }
    }

    /// "Meetings that have ended": one row over `pastEventsAppereance` and
    /// `hideFinishedEventsInMenu`, resolved by `EndedMeetingsVisibility` (hide wins).
    /// Writes both keys.
    private var endedVisibility: Binding<FilterVisibility> {
        Binding(
            get: {
                EndedMeetingsVisibility.resolve(
                    pastRawValue: pastEventsAppereance.rawValue,
                    hideFinished: hideFinishedEventsInMenu
                )
            },
            set: { visibility in
                let stored = EndedMeetingsVisibility.storedValues(for: visibility)
                if let past = PastEventsAppereance(rawValue: stored.past) {
                    pastEventsAppereance = past
                }
                hideFinishedEventsInMenu = stored.hideFinished
            }
        )
    }

    // MARK: - The meeting happening now

    /// Whether a meeting that has started still counts as the next meeting, on every surface.
    private var ongoingSection: some View {
        Section {
            Picker(
                "preferences_filters_ongoing_title".loco(),
                selection: $ongoingEventVisibility
            ) {
                Text("preferences_filters_ongoing_until_next".loco())
                    .tag(OngoingEventVisibility.showTenMinBeforeNext)
                Text("preferences_filters_ongoing_ten_minutes".loco())
                    .tag(OngoingEventVisibility.showTenMinAfter)
                Text("preferences_filters_ongoing_never".loco())
                    .tag(OngoingEventVisibility.hideImmediateAfter)
            }
            helpText("preferences_filters_ongoing_help")
        }
    }

    // MARK: - Title patterns

    private var titlePatternSection: some View {
        Section(header: Text("preferences_filters_title_pattern_title".loco())) {
            helpText("preferences_filters_title_pattern_help")

            TextPatternList(patterns: $filterEventRegexes)

            VStack(alignment: .leading, spacing: 6) {
                Text("preferences_filters_title_pattern_test_title".loco())
                    .font(.subheadline)
                TextField(
                    "preferences_filters_title_pattern_test_placeholder".loco(),
                    text: $patternTestTitle
                )
                .textFieldStyle(.roundedBorder)
                if !patternTestTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                    Label(
                        patternTestResultKey.loco(),
                        systemImage: patternTestHidesTitle ? "eye.slash" : "eye"
                    )
                    .font(.caption)
                    .foregroundStyle(patternTestHidesTitle ? Color.orange : Color.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Whether the sample title would be hidden; calls the real `EventFiltering` rule.
    private var patternTestHidesTitle: Bool {
        EventFiltering.titleIsFilteredOut(patternTestTitle, patterns: filterEventRegexes)
    }

    private var patternTestResultKey: String {
        patternTestHidesTitle
            ? "preferences_filters_title_pattern_test_hidden"
            : "preferences_filters_title_pattern_test_kept"
    }

    // MARK: - Helpers

    private func helpText(_ key: String) -> some View {
        PreferencesHelpText(key: key)
    }

    /// Migrates the retired "show as underlined" value to Dim so the pickers always have a selection.
    private func retireDeletedOptionValues() {
        if let replacement = FilterVocabularyMigration.migrated(showPendingEvents.rawValue),
           let migrated = PendingEventsAppereance(rawValue: replacement) {
            showPendingEvents = migrated
            PunctualLogger.preferences.info("Retired underlined value for showPendingEvents")
        }
        if let replacement = FilterVocabularyMigration.migrated(showTentativeEvents.rawValue),
           let migrated = TentativeEventsAppereance(rawValue: replacement) {
            showTentativeEvents = migrated
            PunctualLogger.preferences.info("Retired underlined value for showTentativeEvents")
        }
    }
}

#Preview {
    FiltersTab().frame(width: 700, height: 700)
}
