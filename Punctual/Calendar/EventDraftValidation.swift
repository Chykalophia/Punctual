//
//  EventDraftValidation.swift
//  Punctual
//
//  Pure draft model and validation rules for the in-app event editor.
//  The UI localizes `EventDraftError`; `EventKitEventWriter` saves a valid draft.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// An event being composed in the editor. A `nil` `calendarID` means no calendar is chosen yet.
struct EventDraft: Equatable, Sendable {
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarID: String?
    var location: String
    var notes: String
    var url: String

    init(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarID: String?,
        location: String = "",
        notes: String = "",
        url: String = ""
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarID = calendarID
        self.location = location
        self.notes = notes
        self.url = url
    }
}

/// A reason a draft cannot be saved.
enum EventDraftError: Equatable, Sendable {
    case emptyTitle
    case endBeforeStart
    case missingCalendar
}

enum EventDraftValidation {
    /// Returns every problem with `draft` in order: title, time, calendar. Empty means savable.
    ///
    /// A timed event needs `endDate` after `startDate`; an all-day event may end on its start date.
    static func validate(_ draft: EventDraft) -> [EventDraftError] {
        var errors: [EventDraftError] = []

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyTitle)
        }

        if draft.isAllDay {
            if draft.endDate < draft.startDate {
                errors.append(.endBeforeStart)
            }
        } else if draft.endDate <= draft.startDate {
            errors.append(.endBeforeStart)
        }

        if draft.calendarID?.isEmpty ?? true {
            errors.append(.missingCalendar)
        }

        return errors
    }
}
