//
//  CommandBarModels.swift
//  Punctual
//
//  Hostless value types for the Command Bar, compiled into PunctualLogic. Localized text is
//  supplied by the app, keeping `.loco()` out of the module. Plain text matching only, no AI.
//

import Foundation

/// Flat projection of an event for the Command Bar. `sourceIndex` maps a row back to the caller's
/// `[MBEvent]`; `subtitle` is preformatted by the app.
struct CommandBarEventInput: Equatable {
    let sourceIndex: Int
    let id: String
    let title: String
    let subtitle: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let hasMeetingLink: Bool
    let location: String?
    let notes: String?
    /// Flattened attendee/organizer names + emails ("people"), for search.
    let attendees: [String]
}

/// The fixed quick actions the Command Bar can run.
enum CommandBarAction: String, Equatable, CaseIterable {
    case joinNext
    case createMeeting
    case openPreferences
    case copyAgenda
    case refreshCalendars
}

/// An action plus its localized presentation and match synonyms, built by the app.
struct CommandBarActionDescriptor: Equatable {
    let action: CommandBarAction
    let title: String
    let subtitle: String?
    /// Already-localized terms the query is matched against (e.g. "join", "next").
    let searchableText: [String]
    /// Shown first (before events) in the empty-query default ordering.
    let isPriority: Bool
}

/// What a row resolves to when the user runs it.
enum CommandBarResult: Equatable {
    case action(CommandBarAction)
    /// The event's id, resolved back to an `MBEvent` by the app.
    case event(String)
}

/// A ranked, display-ready row with localized text; `result` is what to execute.
struct CommandBarResultRow: Equatable {
    let result: CommandBarResult
    let title: String
    let subtitle: String?
    let score: Double
}
