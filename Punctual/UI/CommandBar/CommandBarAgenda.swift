//
//  CommandBarAgenda.swift
//  Punctual
//
//  Hostless plain-text builder for the Command Bar's "Copy today's agenda" action.
//

import Foundation

/// One agenda line. `timeRange` is preformatted by the app.
struct CommandBarAgendaEntry: Equatable {
    let title: String
    let timeRange: String
    let isAllDay: Bool
}

enum CommandBarAgenda {
    /// Builds the agenda: a header line, then one bullet per entry, all-day entries without a time.
    /// `emptyPlaceholder` is used when there are no entries. Both strings arrive localized.
    static func text(
        for entries: [CommandBarAgendaEntry],
        header: String,
        emptyPlaceholder: String
    ) -> String {
        guard !entries.isEmpty else {
            return "\(header)\n\(emptyPlaceholder)"
        }
        var lines = [header]
        for entry in entries {
            let title = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if entry.isAllDay || entry.timeRange.isEmpty {
                lines.append("• \(title)")
            } else {
                lines.append("• \(entry.timeRange)  \(title)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
