//
//  CommandBarSearch.swift
//  Punctual
//
//  Hostless, deterministic ranking for the Command Bar: event ranking via EventSearch plus
//  action matching and the empty-query default ordering.
//

import Foundation

enum CommandBarSearch {
    /// Ranked rows for `query`.
    ///
    /// - Empty query → default ordering: priority actions, then today's upcoming
    ///   events by proximity, then the remaining actions.
    /// - Non-empty query → actions and events scored independently and
    ///   interleaved by score (descending), ties broken stably by input order.
    static func results(
        query: String,
        events: [CommandBarEventInput],
        actions: [CommandBarActionDescriptor],
        now: Date,
        calendar _: Calendar
    ) -> [CommandBarResultRow] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultOrdering(events: events, actions: actions, now: now)
        }

        var scored: [(row: CommandBarResultRow, order: Int)] = []
        var order = 0

        for descriptor in actions {
            if let score = actionScore(query: trimmed, descriptor: descriptor) {
                scored.append((
                    CommandBarResultRow(
                        result: .action(descriptor.action),
                        title: descriptor.title,
                        subtitle: descriptor.subtitle,
                        score: score
                    ),
                    order
                ))
            }
            order += 1
        }

        let searchable = events.map {
            SearchableEvent(
                sourceIndex: $0.sourceIndex,
                id: $0.id,
                title: $0.title,
                notes: $0.notes,
                location: $0.location,
                attendees: $0.attendees
            )
        }
        let eventsByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        for hit in EventSearch.rank(searchable, query: trimmed) {
            guard let event = eventsByID[hit.id] else { continue }
            scored.append((
                CommandBarResultRow(
                    result: .event(event.id),
                    title: event.title,
                    subtitle: event.subtitle,
                    score: hit.score
                ),
                order
            ))
            order += 1
        }

        return scored
            .sorted { $0.row.score != $1.row.score ? $0.row.score > $1.row.score : $0.order < $1.order }
            .map(\.row)
    }

    // MARK: - Default (empty-query) ordering

    private static func defaultOrdering(
        events: [CommandBarEventInput],
        actions: [CommandBarActionDescriptor],
        now: Date
    ) -> [CommandBarResultRow] {
        var rows: [CommandBarResultRow] = []

        for descriptor in actions where descriptor.isPriority {
            rows.append(actionRow(descriptor))
        }

        let upcoming = events
            .filter { $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        for event in upcoming {
            rows.append(
                CommandBarResultRow(
                    result: .event(event.id),
                    title: event.title,
                    subtitle: event.subtitle,
                    score: 0
                )
            )
        }

        for descriptor in actions where !descriptor.isPriority {
            rows.append(actionRow(descriptor))
        }

        return rows
    }

    private static func actionRow(_ descriptor: CommandBarActionDescriptor) -> CommandBarResultRow {
        CommandBarResultRow(
            result: .action(descriptor.action),
            title: descriptor.title,
            subtitle: descriptor.subtitle,
            score: 0
        )
    }

    // MARK: - Action scoring

    /// Matches every term of `query` against an action's title and synonyms. Returns the summed
    /// best-tier score, or `nil` if any term misses.
    private static func actionScore(query: String, descriptor: CommandBarActionDescriptor) -> Double? {
        let haystack = ([descriptor.title] + descriptor.searchableText).map(TextNormalization.fold)
        let terms = TextNormalization.fold(query)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard !terms.isEmpty else { return nil }

        var total = 0.0
        for term in terms {
            var best = 0.0
            for field in haystack {
                best = max(best, matchTier(term: term, in: field))
            }
            guard best > 0 else { return nil }
            total += best
        }
        return total
    }

    /// Match strength of `term` in an already-folded `field`: exact = 4,
    /// prefix = 3, word-boundary prefix = 2, substring = 1, none = 0.
    ///
    /// Internal so `SettingsIndex` ranks settings on the same scale.
    static func matchTier(term: String, in field: String) -> Double {
        guard !field.isEmpty, !term.isEmpty else { return 0 }
        if field == term { return 4 }
        if field.hasPrefix(term) { return 3 }
        let separators: Set<Character> = [" ", "-", "_", ".", ",", "/", ":"]
        for token in field.split(whereSeparator: { separators.contains($0) }) where token.hasPrefix(term) {
            return 2
        }
        if field.contains(term) { return 1 }
        return 0
    }
}
