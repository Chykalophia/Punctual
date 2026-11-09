//
//  ReminderSelection.swift
//  Punctual
//
//  Pure selection, sorting and snooze logic for Apple Reminders in the menu.
//

import Foundation

/// Projection of a reminder for filtering and sorting. `sourceIndex` maps back to the caller's array.
struct ReminderSelectionItem: Equatable {
    let sourceIndex: Int
    let id: String
    let dueDate: Date?
    let hasTime: Bool
    /// EventKit priority: 0 = none, 1 = high … 9 = low.
    let priority: Int
    let isCompleted: Bool
}

enum ReminderSelection {
    /// Incomplete reminders due today, optionally with overdue ones; reminders without a due date are excluded.
    ///
    /// Sorted overdue first, then by due date, then priority (high first), then `sourceIndex`.
    static func dueToday(
        from reminders: [ReminderSelectionItem],
        now: Date,
        calendar: Calendar,
        includeOverdue: Bool
    ) -> [ReminderSelectionItem] {
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let filtered = reminders.filter { item in
            guard !item.isCompleted, let due = item.dueDate else { return false }
            guard due < endOfDay else { return false }        // due today or earlier
            if due < startOfDay { return includeOverdue }      // overdue only if requested
            return true
        }

        return filtered.sorted { lhs, rhs in
            let lhsOverdue = (lhs.dueDate ?? .distantFuture) < startOfDay
            let rhsOverdue = (rhs.dueDate ?? .distantFuture) < startOfDay
            if lhsOverdue != rhsOverdue { return lhsOverdue }

            let lhsDue = lhs.dueDate ?? .distantFuture
            let rhsDue = rhs.dueDate ?? .distantFuture
            if lhsDue != rhsDue { return lhsDue < rhsDue }

            if lhs.priority != rhs.priority { return priorityRank(lhs.priority) < priorityRank(rhs.priority) }
            return lhs.sourceIndex < rhs.sourceIndex
        }
    }

    /// Maps EventKit priority (0 = none, 1 high … 9 low) to a sort rank where a
    /// higher priority sorts first and "none" sorts last.
    private static func priorityRank(_ priority: Int) -> Int {
        priority == 0 ? Int.max : priority
    }
}

/// Snooze targets for a reminder; snoozing moves the reminder's due date in Apple Reminders.
enum ReminderSnoozeOption: String, CaseIterable, Equatable {
    case laterToday
    case thisEvening
    case tomorrow
}

enum ReminderSnoozePolicy {
    /// New due date for a snooze option, handling already-passed target hours:
    /// - `.laterToday`   → now + 1 hour.
    /// - `.thisEvening`  → today at `eveningHour`, or now + 1 hour if already past.
    /// - `.tomorrow`     → tomorrow at `morningHour`.
    static func newDueDate(
        from now: Date,
        option: ReminderSnoozeOption,
        calendar: Calendar,
        eveningHour: Int = 18,
        morningHour: Int = 9
    ) -> Date {
        switch option {
        case .laterToday:
            return now.addingTimeInterval(3600)
        case .thisEvening:
            let startOfDay = calendar.startOfDay(for: now)
            let evening = calendar.date(bySettingHour: eveningHour, minute: 0, second: 0, of: startOfDay)
                ?? now.addingTimeInterval(3600)
            return evening > now ? evening : now.addingTimeInterval(3600)
        case .tomorrow:
            let startOfDay = calendar.startOfDay(for: now)
            let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
            return calendar.date(bySettingHour: morningHour, minute: 0, second: 0, of: tomorrowStart)
                ?? tomorrowStart
        }
    }
}
