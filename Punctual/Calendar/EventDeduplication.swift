//
//  EventDeduplication.swift
//  Punctual
//
//  Pure cross-calendar and cross-source duplicate detection, keyed on the shared
//  external identifier or on a normalized title, start minute and all-day composite.
//

import Foundation

/// The fields of an event that duplicate detection needs.
struct DeduplicationEvent {
    /// Index of the event in the caller's array, returned for survivors.
    let sourceIndex: Int
    let externalIdentifier: String?
    let title: String
    let startDate: Date
    /// Deliberately not part of the identity key: copies of one meeting often disagree on the end.
    let endDate: Date
    let isAllDay: Bool
    /// Which copy of a collapsed meeting survives; lower wins, ties go to the earlier position.
    var sourcePriority: Int = 0
}

enum EventDeduplication {
    /// Returns the `sourceIndex` of each event to keep, dropping duplicates.
    /// Output stays in the input's relative order.
    ///
    /// Duplicates are grouped transitively (A matches B by composite, B matches C
    /// by identifier: one meeting), then one survivor is chosen per group.
    static func keptIndices(_ events: [DeduplicationEvent]) -> [Int] {
        guard !events.isEmpty else { return [] }

        var groups = DisjointSet(count: events.count)

        // Either signal alone merges two events; do not require both or short-circuit on the identifier.
        var firstAtComposite: [String: Int] = [:]
        var firstAtIdentifier: [String: Int] = [:]

        for (position, event) in events.enumerated() {
            let composite = compositeKey(for: event)
            if let existing = firstAtComposite[composite] {
                groups.union(existing, position)
            } else {
                firstAtComposite[composite] = position
            }

            if let identifier = sharedIdentifier(for: event) {
                if let existing = firstAtIdentifier[identifier] {
                    groups.union(existing, position)
                } else {
                    firstAtIdentifier[identifier] = position
                }
            }
        }

        // One survivor per group: lowest `sourcePriority`, ties to the earlier position.
        var survivorByGroup: [Int: Int] = [:]
        for position in events.indices {
            let group = groups.root(of: position)
            guard let incumbent = survivorByGroup[group] else {
                survivorByGroup[group] = position
                continue
            }
            if events[position].sourcePriority < events[incumbent].sourcePriority {
                survivorByGroup[group] = position
            }
        }

        let survivors = Set(survivorByGroup.values)
        return events.indices
            .filter { survivors.contains($0) }
            .map { events[$0].sourceIndex }
    }

    /// The provider's shared identifier, or `nil` when absent or empty.
    private static func sharedIdentifier(for event: DeduplicationEvent) -> String? {
        guard let identifier = event.externalIdentifier, !identifier.isEmpty else { return nil }
        return identifier
    }

    /// Normalized title, start minute and all-day flag: what the user sees on the row.
    private static func compositeKey(for event: DeduplicationEvent) -> String {
        "composite:\(normalizedTitle(event.title))|\(startMinute(event))|\(event.isAllDay)"
    }

    /// Case-, diacritic- and whitespace-insensitive title, independent of the current locale.
    private static func normalizedTitle(_ title: String) -> String {
        title
            .folding(options: .diacriticInsensitive, locale: nil)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Whole minutes since the reference date, truncated (not rounded) to match the displayed minute.
    private static func startMinute(_ event: DeduplicationEvent) -> Int {
        Int((event.startDate.timeIntervalSinceReferenceDate / 60).rounded(.down))
    }
}

/// Minimal union-find over array positions, with path halving and union by size.
private struct DisjointSet {
    private var parent: [Int]
    private var size: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        size = Array(repeating: 1, count: count)
    }

    mutating func root(of element: Int) -> Int {
        var current = element
        while parent[current] != current {
            parent[current] = parent[parent[current]]
            current = parent[current]
        }
        return current
    }

    mutating func union(_ lhs: Int, _ rhs: Int) {
        let lhsRoot = root(of: lhs)
        let rhsRoot = root(of: rhs)
        guard lhsRoot != rhsRoot else { return }
        let (larger, smaller) = size[lhsRoot] >= size[rhsRoot]
            ? (lhsRoot, rhsRoot)
            : (rhsRoot, lhsRoot)
        parent[smaller] = larger
        size[larger] += size[smaller]
    }
}
