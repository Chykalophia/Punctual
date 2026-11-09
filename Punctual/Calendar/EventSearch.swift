//
//  EventSearch.swift
//  Punctual
//
//  Pure, deterministic ranked text search over `SearchableEvent` projections,
//  used by the Command Bar.
//

import Foundation

/// Projection of an event for ranked search. `sourceIndex` maps a result back to the caller's array.
struct SearchableEvent: Equatable {
    let sourceIndex: Int
    let id: String
    let title: String
    let notes: String?
    let location: String?
    /// Attendee and organizer names and emails.
    let attendees: [String]
}

/// Per-field scoring weights; a match in a higher-weighted field ranks the event higher.
struct SearchFieldWeights: Equatable {
    let title: Double
    let attendees: Double
    let location: Double
    let notes: Double

    /// Title, then people, then location, then notes.
    static let `default` = SearchFieldWeights(title: 1.0, attendees: 0.7, location: 0.6, notes: 0.4)
}

/// A ranked search hit. `sourceIndex` indexes back into the caller's array.
struct EventSearchResult: Equatable {
    let sourceIndex: Int
    let id: String
    let score: Double
}

/// Case-, diacritic- and width-insensitive folding for event fields and query terms.
/// `locale: nil` keeps results locale-independent (no Turkish dotless-i surprises).
enum TextNormalization {
    static func fold(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: nil
        )
    }
}

enum EventSearch {
    /// Ranks `events` best-first for `query`.
    ///
    /// - An empty or whitespace query returns every event in input order with score 0.
    /// - Multi-term queries use AND semantics: an event must match every term in some field.
    /// - Score is the sum of each term's best-field score; ties keep input order.
    static func rank(
        _ events: [SearchableEvent],
        query: String,
        weights: SearchFieldWeights = .default
    ) -> [EventSearchResult] {
        let terms = TextNormalization.fold(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)

        guard !terms.isEmpty else {
            return events.map { EventSearchResult(sourceIndex: $0.sourceIndex, id: $0.id, score: 0) }
        }

        var results: [EventSearchResult] = []
        for event in events {
            let fields = FoldedFields(event: event)
            var total = 0.0
            var matchedAll = true
            for term in terms {
                let best = bestFieldScore(term: term, fields: fields, weights: weights)
                guard best > 0 else {
                    matchedAll = false
                    break
                }
                total += best
            }
            if matchedAll {
                results.append(EventSearchResult(sourceIndex: event.sourceIndex, id: event.id, score: total))
            }
        }

        return results.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.sourceIndex < $1.sourceIndex
        }
    }

    // MARK: - Internal

    /// An event's fields, folded once per event rather than once per term.
    private struct FoldedFields {
        let title: String
        let location: String?
        let notes: String?
        let attendees: [String]

        init(event: SearchableEvent) {
            title = TextNormalization.fold(event.title)
            location = event.location.map(TextNormalization.fold)
            notes = event.notes.map(TextNormalization.fold)
            attendees = event.attendees.map(TextNormalization.fold)
        }
    }

    private static func bestFieldScore(
        term: String,
        fields: FoldedFields,
        weights: SearchFieldWeights
    ) -> Double {
        var best = weights.title * matchTier(term: term, in: fields.title)
        if let location = fields.location {
            best = max(best, weights.location * matchTier(term: term, in: location))
        }
        if let notes = fields.notes {
            best = max(best, weights.notes * matchTier(term: term, in: notes))
        }
        for attendee in fields.attendees {
            best = max(best, weights.attendees * matchTier(term: term, in: attendee))
        }
        return best
    }

    /// Match strength of `term` within an already-folded `field`:
    /// whole-field exact = 4, field prefix = 3, word-boundary prefix = 2,
    /// substring = 1, none = 0.
    private static func matchTier(term: String, in field: String) -> Double {
        guard !field.isEmpty, !term.isEmpty else { return 0 }
        if field == term { return 4 }
        if field.hasPrefix(term) { return 3 }
        if hasWordBoundaryPrefix(term: term, in: field) { return 2 }
        if field.contains(term) { return 1 }
        return 0
    }

    private static func hasWordBoundaryPrefix(term: String, in field: String) -> Bool {
        let separators: Set<Character> = [" ", "-", "_", ".", ",", "/", ":"]
        for token in field.split(whereSeparator: { separators.contains($0) }) where token.hasPrefix(term) {
            return true
        }
        return false
    }
}
