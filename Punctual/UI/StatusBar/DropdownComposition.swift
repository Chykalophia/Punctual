//
//  DropdownComposition.swift
//  Punctual
//
//  Hostless model for the composable dropdown: module order, enabled set, and
//  separator placement. Unknown stored raw values are ignored, never fatal.
//

import Foundation

/// A reorderable, toggleable section of the dropdown.
///
/// The Preferences footer is deliberately not a module: it is always pinned last
/// so Settings and Quit stay reachable.
enum DropdownModule: String, CaseIterable, Codable, Hashable {
    /// The day-summary greeting header at the very top of the dropdown.
    case greeting
    /// The day-relative timeline bar.
    case timeline
    /// The next/current meeting control card (or its empty state).
    case meeting
    /// Today's (and optionally tomorrow's) date sections plus reminders.
    case agenda
    /// Join / create / quick-actions rows.
    case join
    /// The saved bookmarks section.
    case bookmarks

    /// A compact month grid (about 200pt tall). Off by default.
    case calendar

    /// Whether this module is a list of actions rather than content. The panel
    /// draws a rule only above action lists, never between content modules.
    var isActionList: Bool {
        switch self {
        case .join, .bookmarks: true
        case .greeting, .timeline, .meeting, .agenda, .calendar: false
        }
    }
}

enum DropdownSeparatorPolicy {
    /// Indices in `modules` that should be preceded by a rule.
    ///
    /// One rule above each run of consecutive action lists; never at index 0.
    static func separatorIndices(for modules: [DropdownModule]) -> Set<Int> {
        var indices: Set<Int> = []
        for (index, module) in modules.enumerated() where module.isActionList && index > 0 {
            guard !modules[index - 1].isActionList else { continue }
            indices.insert(index)
        }
        return indices
    }
}

/// An ordered list of dropdown modules.
struct DropdownComposition: Equatable {
    var modules: [DropdownModule]

    /// The default order, used for a fresh install or an empty stored order.
    ///
    /// Every module must appear here, including ones disabled by default:
    /// `resolve` back-fills missing modules only from this list.
    static let standard = DropdownComposition(
        modules: [.greeting, .timeline, .meeting, .calendar, .agenda, .join, .bookmarks]
    )
}

/// Resolves the stored order and per-module enabled set into the modules to render.
enum DropdownCompositionPolicy {
    /// Resolves the visible, ordered modules from a stored raw order and the set
    /// of enabled module raw values.
    ///
    /// 1. Parse `rawOrder` into `DropdownModule`, dropping unknowns and de-duping
    ///    (first occurrence wins).
    /// 2. Append any module absent from `rawOrder`, in `standard` order, so
    ///    newly added modules surface for users with an older stored order.
    /// 3. Keep only modules whose `rawValue` is in `enabled`.
    static func resolve(order rawOrder: [String], enabled: Set<String>) -> [DropdownModule] {
        var seen = Set<DropdownModule>()
        var ordered: [DropdownModule] = []

        for raw in rawOrder {
            guard let module = DropdownModule(rawValue: raw) else { continue }
            if seen.insert(module).inserted {
                ordered.append(module)
            }
        }

        for module in DropdownComposition.standard.modules where seen.insert(module).inserted {
            ordered.append(module)
        }

        return ordered.filter { enabled.contains($0.rawValue) }
    }

    // swiftlint:disable function_parameter_count
    /// The raw values of the modules whose toggle is on: the `enabled` set for
    /// `resolve(order:enabled:)`. Shared by the dropdown and the Display-tab
    /// preview so the two cannot drift.
    static func enabledRawValues(
        greeting: Bool,
        timeline: Bool,
        meeting: Bool,
        agenda: Bool,
        join: Bool,
        bookmarks: Bool,
        calendar: Bool
    ) -> Set<String> {
        // swiftlint:enable function_parameter_count
        var enabled = Set<String>()
        if greeting { enabled.insert(DropdownModule.greeting.rawValue) }
        if timeline { enabled.insert(DropdownModule.timeline.rawValue) }
        if meeting { enabled.insert(DropdownModule.meeting.rawValue) }
        if agenda { enabled.insert(DropdownModule.agenda.rawValue) }
        if join { enabled.insert(DropdownModule.join.rawValue) }
        if bookmarks { enabled.insert(DropdownModule.bookmarks.rawValue) }
        if calendar { enabled.insert(DropdownModule.calendar.rawValue) }
        return enabled
    }
}
