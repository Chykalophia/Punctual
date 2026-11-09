//
//  RemindersStore.swift
//  Punctual
//
//  EventKit service for Apple Reminders shown in the menu: access, fetch, complete
//  and reschedule. Uses its own `EKEventStore` so reminders permission is requested
//  separately from calendars, and only on opt-in.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import EventKit
import Foundation

/// `Sendable` wrapper around a private reminders `EKEventStore`.
/// Async methods are non-isolated and run off the main actor.
final class RemindersStore: Sendable {
    /// The shared instance; all reminders access must go through one `EKEventStore`.
    static let shared = RemindersStore()

    private let store = EKEventStore()

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    /// Whether the app currently has read/write access to reminders.
    var isAccessGranted: Bool {
        Self.isGranted(authorizationStatus)
    }

    static func isGranted(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    /// Whether access was denied or restricted, so requesting again will not prompt.
    static func isDenied(_ status: EKAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }

    /// Requests reminders access; the only entry point that shows the system permission prompt.
    /// - Returns: Whether access was granted.
    @discardableResult
    func requestAccess() async -> Bool {
        await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let handler: @Sendable (Bool, (any Error)?) -> Void = { granted, error in
                if let error {
                    PunctualLogger.calendar.error(
                        "Reminders access request failed: \(String(describing: error), privacy: .private)"
                    )
                }
                continuation.resume(returning: granted)
            }

            if #available(macOS 14, *) {
                store.requestFullAccessToReminders(completion: handler)
            } else {
                store.requestAccess(to: .reminder, completion: handler)
            }
        }
    }

    /// Incomplete reminders due today or earlier, or `[]` without access.
    func fetchDueToday() async -> [MBReminder] {
        guard isAccessGranted else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: endOfDay,
            calendars: nil
        )

        // Map inside the completion so no non-Sendable EKReminder crosses the continuation.
        return await withCheckedContinuation { (continuation: CheckedContinuation<[MBReminder], Never>) in
            _ = store.fetchReminders(matching: predicate) { reminders in
                let mapped = (reminders ?? []).map { makeReminder(from: $0, now: now, calendar: calendar) }
                continuation.resume(returning: mapped)
            }
        }
    }

    /// Marks the reminder with this identifier complete and commits.
    func complete(id: String) async {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            PunctualLogger.calendar.error(
                "Reminder to complete not found: \(id, privacy: .private)"
            )
            return
        }
        reminder.isCompleted = true
        save(reminder, action: "complete", id: id)
    }

    /// Moves the reminder's due date to `date` and adds an alarm at that time, then commits.
    func reschedule(id: String, to date: Date) async {
        guard let reminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            PunctualLogger.calendar.error(
                "Reminder to reschedule not found: \(id, privacy: .private)"
            )
            return
        }
        let calendar = Calendar.current
        reminder.dueDateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        reminder.addAlarm(EKAlarm(absoluteDate: date))
        save(reminder, action: "reschedule", id: id)
    }

    private func save(_ reminder: EKReminder, action: String, id: String) {
        do {
            try store.save(reminder, commit: true)
        } catch {
            PunctualLogger.calendar.error(
                "Reminder \(action, privacy: .public) save failed for \(id, privacy: .private): \(String(describing: error), privacy: .private)"
            )
        }
    }
}

/// Maps an `EKReminder` to the Sendable `MBReminder` value type.
private func makeReminder(from reminder: EKReminder, now: Date, calendar: Calendar) -> MBReminder {
    let components = reminder.dueDateComponents
    let dueDate = components.flatMap { calendar.date(from: $0) }
    let hasTime = components?.hour != nil
    let startOfToday = calendar.startOfDay(for: now)
    let isOverdue = dueDate.map { $0 < startOfToday } ?? false

    return MBReminder(
        id: reminder.calendarItemIdentifier,
        title: reminder.title ?? "",
        notes: reminder.notes,
        dueDate: dueDate,
        hasTime: hasTime,
        priority: reminder.priority,
        isCompleted: reminder.isCompleted,
        listTitle: reminder.calendar?.title ?? "",
        listColor: reminder.calendar?.color ?? NSColor.systemGray,
        isOverdue: isOverdue
    )
}
