//
//  FilterPresets.swift
//  Punctual
//
//  Hostless logic for the Filters pane: presets, the merged "ended meetings"
//  row, and the retired-value migration. Values are raw strings, not the app's
//  `Defaults` enums, so this compiles into PunctualLogic.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// The `Defaults` key names the Filters presets write.
enum FilterDefaultsKey {
    static let allDay = "allDayEvents"
    static let noLink = "nonAllDayEvents"
    static let solo = "personalEventsAppereance"
    static let pending = "showPendingEvents"
    static let tentative = "showTentativeEvents"
    static let declined = "declinedEventsAppereance"
    static let ended = "pastEventsAppereance"
    static let hideFinished = "hideFinishedEventsInMenu"
}

/// Named sets of values for the per-kind filter rows.
///
/// `custom` is never stored; it is what `detect(_:)` returns when the values match no named preset.
enum FilterPreset: String, CaseIterable, Sendable {
    case everything
    case meetingsOnly
    case acceptedOnly
    case custom

    var titleKey: String {
        switch self {
        case .everything: "preferences_filters_preset_everything"
        case .meetingsOnly: "preferences_filters_preset_meetings_only"
        case .acceptedOnly: "preferences_filters_preset_accepted_only"
        case .custom: "preferences_filters_preset_custom"
        }
    }

    /// Stored key name → raw value. Empty for `.custom`, which writes nothing.
    var values: [String: String] {
        switch self {
        case .everything:
            [
                FilterDefaultsKey.allDay: "show",
                FilterDefaultsKey.noLink: "show",
                FilterDefaultsKey.solo: "show_active",
                FilterDefaultsKey.pending: "show",
                FilterDefaultsKey.tentative: "show",
                // `DeclinedEventsAppereance` has no plain `show`; `strikethrough` is its visible value.
                FilterDefaultsKey.declined: "strikethrough",
                FilterDefaultsKey.ended: "show_inactive",
                FilterDefaultsKey.hideFinished: "false"
            ]
        case .meetingsOnly:
            [
                FilterDefaultsKey.allDay: "hide",
                FilterDefaultsKey.noLink: "hide_without_meeting_link",
                FilterDefaultsKey.solo: "hide",
                FilterDefaultsKey.pending: "show",
                FilterDefaultsKey.tentative: "show",
                FilterDefaultsKey.declined: "hide",
                FilterDefaultsKey.ended: "hide",
                FilterDefaultsKey.hideFinished: "true"
            ]
        case .acceptedOnly:
            [
                FilterDefaultsKey.allDay: "hide",
                FilterDefaultsKey.noLink: "hide_without_meeting_link",
                FilterDefaultsKey.solo: "hide",
                FilterDefaultsKey.pending: "hide",
                FilterDefaultsKey.tentative: "hide",
                FilterDefaultsKey.declined: "hide",
                FilterDefaultsKey.ended: "hide",
                FilterDefaultsKey.hideFinished: "true"
            ]
        case .custom:
            [:]
        }
    }

    /// The named preset whose values exactly match `values`, else `.custom`.
    static func detect(_ values: [String: String]) -> FilterPreset {
        allCases.first { $0 != .custom && $0.values == values } ?? .custom
    }
}

/// The Show / Dim / Hide values offered by the Filters rows.
enum FilterVisibility: String, CaseIterable, Sendable {
    case show
    case dim
    case hide

    var titleKey: String {
        switch self {
        case .show: "preferences_filters_value_show"
        case .dim: "preferences_filters_value_dim"
        case .hide: "preferences_filters_value_hide"
        }
    }
}

/// The "Meetings that have ended" row over `pastEventsAppereance` and `hideFinishedEventsInMenu`.
///
/// Hide wins: if either key hides, the row reads Hide.
enum EndedMeetingsVisibility {
    /// Reads the merged row from both stored values.
    static func resolve(pastRawValue: String, hideFinished: Bool) -> FilterVisibility {
        if hideFinished || pastRawValue == "hide" { return .hide }
        return pastRawValue == "show_inactive" ? .dim : .show
    }

    /// The values to write to both keys for `visibility`, keeping them consistent.
    static func storedValues(for visibility: FilterVisibility) -> (past: String, hideFinished: Bool) {
        switch visibility {
        case .show: ("show_active", false)
        case .dim: ("show_inactive", false)
        case .hide: ("hide", true)
        }
    }
}

/// Maps the retired "show as underlined" value to Dim.
///
/// The case still exists on the stored enums so old values decode; it is no longer offered in the UI.
enum FilterVocabularyMigration {
    static let retiredRawValue = "show_underlined"
    static let replacementRawValue = "show_inactive"

    /// The value to store instead, or `nil` when the stored value is fine.
    static func migrated(_ rawValue: String) -> String? {
        rawValue == retiredRawValue ? replacementRawValue : nil
    }
}
