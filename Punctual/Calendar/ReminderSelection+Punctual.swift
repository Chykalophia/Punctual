//
//  ReminderSelection+Punctual.swift
//  Punctual
//
//  Maps `MBReminder` onto the pure `ReminderSelection` logic.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

extension ReminderSelectionItem {
    init(reminder: MBReminder, sourceIndex: Int) {
        self.init(
            sourceIndex: sourceIndex,
            id: reminder.id,
            dueDate: reminder.dueDate,
            hasTime: reminder.hasTime,
            priority: reminder.priority,
            isCompleted: reminder.isCompleted
        )
    }
}

extension Array where Element == MBReminder {
    /// Incomplete reminders due today, optionally with overdue ones, sorted by `ReminderSelection.dueToday`.
    func dueToday(
        now: Date = Date(),
        includeOverdue: Bool,
        calendar: Calendar = .current
    ) -> [MBReminder] {
        let items = enumerated().map { index, reminder in
            ReminderSelectionItem(reminder: reminder, sourceIndex: index)
        }
        return ReminderSelection.dueToday(
            from: items,
            now: now,
            calendar: calendar,
            includeOverdue: includeOverdue
        )
        .map { self[$0.sourceIndex] }
    }
}
