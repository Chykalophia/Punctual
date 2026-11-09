//
//  CalendarListPresentation.swift
//  Punctual
//
//  Hostless grouping, disambiguation and filtering for the Calendars pane's
//  "Calendars to show" list. Uses plain values rather than `MBCalendar` (which
//  carries an `NSColor`) so it compiles into PunctualLogic.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// One calendar, reduced to what the picker needs to group, disambiguate and search it.
public struct CalendarPickerItem: Hashable, Sendable {
    public let id: String
    public let title: String
    /// The account the calendar belongs to (`MBCalendar.source`).
    public let source: String
    /// The account address, when the source exposes one.
    public let email: String?
    /// The calendar source this calendar came from.
    public let provider: CalendarSourceKind

    public init(
        id: String,
        title: String,
        source: String,
        email: String?,
        provider: CalendarSourceKind = .macOSEventKit
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.email = email
        self.provider = provider
    }
}

/// One checkbox row.
public struct CalendarPickerRow: Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    /// The account address, only when another calendar in the full list shares this name; otherwise `nil`.
    public let subtitle: String?
}

/// One account's worth of rows.
public struct CalendarAccountGroup: Hashable, Sendable, Identifiable {
    /// `"<provider>|<source>"`; the account name alone is not unique across sources.
    public let id: String
    /// The raw account/source string, without the provider prefix in `id`.
    public let account: String
    /// The account name to display. Empty when `titleKey` supplies it instead.
    public let title: String
    /// Localization key used instead of `title`; non-nil only for the unnamed source ("Other").
    public let titleKey: String?
    /// The source these calendars came from, shown beside the account name.
    public let provider: CalendarSourceKind
    /// Localization key naming `provider` on screen.
    public let providerTitleKey: String
    public let rows: [CalendarPickerRow]
}

public enum CalendarListPresentation {
    /// `MBCalendar` substitutes this when EventKit hands over no source name.
    public static let unknownSource = "unknown"
    /// Localization key for the unnamed source's display name.
    public static let otherSourceTitleKey = "preferences_calendars_source_other"

    /// The grouped, disambiguated, filtered list, in display order.
    ///
    /// Groups by source then account, named accounts alphabetically with the unnamed
    /// source last. A row gets its account email as a subtitle when its name occurs
    /// more than once in `items`.
    ///
    /// - Parameters:
    ///   - items: Every available calendar.
    ///   - query: Free text matched against calendar name, account name and address. Blank shows everything.
    /// - Returns: The account groups to render, in display order.
    public static func groups(
        for items: [CalendarPickerItem],
        query: String = ""
    ) -> [CalendarAccountGroup] {
        // Counted over the unfiltered list so a search keeps the disambiguating subtitle.
        var titleCounts: [String: Int] = [:]
        for item in items {
            titleCounts[TextNormalization.fold(item.title), default: 0] += 1
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = trimmedQuery.isEmpty
            ? items
            : items.filter { matches($0, foldedQuery: TextNormalization.fold(trimmedQuery)) }

        let byAccount = Dictionary(grouping: matching) {
            AccountKey(provider: $0.provider, source: $0.source)
        }

        return byAccount.keys
            .sorted(by: accountsInDisplayOrder)
            .map { key in
                let rows = (byAccount[key] ?? [])
                    .sorted(by: itemsInDisplayOrder)
                    .map { item in
                        CalendarPickerRow(
                            id: item.id,
                            title: item.title,
                            subtitle: (titleCounts[TextNormalization.fold(item.title)] ?? 0) > 1
                                ? item.email
                                : nil
                        )
                    }
                let isUnnamed = key.source == unknownSource
                return CalendarAccountGroup(
                    id: "\(key.provider.rawValue)|\(key.source)",
                    account: key.source,
                    title: isUnnamed ? "" : key.source,
                    titleKey: isUnnamed ? otherSourceTitleKey : nil,
                    provider: key.provider,
                    providerTitleKey: key.provider.shortTitleKey,
                    rows: rows
                )
            }
    }

    /// One account within one source; the same account name can arrive from both sources.
    private struct AccountKey: Hashable {
        let provider: CalendarSourceKind
        let source: String
    }

    /// Every calendar id in `groups`, in reading order.
    public static func visibleIDs(in groups: [CalendarAccountGroup]) -> [String] {
        groups.flatMap { $0.rows.map(\.id) }
    }

    // MARK: - Ordering and matching

    /// Sources in `CalendarSourceKind.displayOrder`, then accounts within each source.
    private static func accountsInDisplayOrder(_ lhs: AccountKey, _ rhs: AccountKey) -> Bool {
        guard lhs.provider == rhs.provider else {
            let order = CalendarSourceKind.displayOrder
            return (order.firstIndex(of: lhs.provider) ?? 0)
                < (order.firstIndex(of: rhs.provider) ?? 0)
        }
        return sourcesInDisplayOrder(lhs.source, rhs.source)
    }

    /// Named accounts alphabetically (case- and diacritic-insensitive), the unnamed source last.
    private static func sourcesInDisplayOrder(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == unknownSource || rhs == unknownSource {
            return rhs == unknownSource && lhs != unknownSource
        }
        let folded = TextNormalization.fold(lhs).compare(TextNormalization.fold(rhs))
        return folded == .orderedSame ? lhs < rhs : folded == .orderedAscending
    }

    /// Calendars by name, then by id for a stable order.
    private static func itemsInDisplayOrder(
        _ lhs: CalendarPickerItem,
        _ rhs: CalendarPickerItem
    ) -> Bool {
        let folded = TextNormalization.fold(lhs.title).compare(TextNormalization.fold(rhs.title))
        return folded == .orderedSame ? lhs.id < rhs.id : folded == .orderedAscending
    }

    private static func matches(_ item: CalendarPickerItem, foldedQuery: String) -> Bool {
        let haystack = [item.title, item.source, item.email ?? ""]
        return haystack.contains { TextNormalization.fold($0).contains(foldedQuery) }
    }
}
