//
//  MBReminder.swift
//  Punctual
//
//  Sendable snapshot of an Apple Reminder shown in the menu's Today section.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit

public struct MBReminder: Identifiable, Hashable, Sendable {
    /// EventKit `calendarItemIdentifier`, used to re-fetch the reminder for writes.
    public let id: String
    public let title: String
    public let notes: String?
    public let dueDate: Date?
    /// Whether the due date includes a time of day; when false no clock time is shown.
    public let hasTime: Bool
    /// EventKit priority: 0 = none, 1 = high … 9 = low.
    public let priority: Int
    public let isCompleted: Bool
    public let listTitle: String
    public let listColor: NSColor
    /// Whether the due date is before the start of today.
    public let isOverdue: Bool

    public init(
        id: String,
        title: String,
        notes: String?,
        dueDate: Date?,
        hasTime: Bool,
        priority: Int,
        isCompleted: Bool,
        listTitle: String,
        listColor: NSColor,
        isOverdue: Bool
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.priority = priority
        self.isCompleted = isCompleted
        self.listTitle = listTitle
        self.listColor = listColor
        self.isOverdue = isOverdue
    }
}
