//
//  EventKitEventWriter.swift
//  Punctual
//
//  Creates, updates and deletes calendar events through `EKEventStore.shared`
//  from a validated `EventDraft`.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import EventKit
import Foundation

extension EventEditSpan {
    /// The EventKit span for this edit scope.
    var ekSpan: EKSpan {
        self == .thisAndFuture ? .futureEvents : .thisEvent
    }
}

enum EventKitWriteError: LocalizedError {
    case calendarNotFound
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .calendarNotFound:
            return "The selected calendar is no longer available"
        case .eventNotFound:
            return "The event could not be found in the calendar store"
        }
    }
}

/// Stateless writer over `EKEventStore.shared`. Async methods run off the main actor.
///
/// Each `EKEvent` is fetched, mutated and saved within one method body so it never
/// crosses a suspension point (it is not Sendable).
struct EventKitEventWriter: Sendable {
    static let shared = EventKitEventWriter()

    /// Calendars that allow content modifications, for the editor's calendar picker.
    @MainActor
    func writableCalendars() -> [MBCalendar] {
        EKEventStore.shared.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map { calendar in
                MBCalendar(
                    title: calendar.title,
                    id: calendar.calendarIdentifier,
                    source: calendar.source.title,
                    email: getGmailAccount(calendar.source.description),
                    color: calendar.color
                )
            }
    }

    /// Creates a new event from `draft` and returns its EventKit identifier.
    func create(draft: EventDraft) async throws -> String {
        let store = EKEventStore.shared
        guard let calendarID = draft.calendarID,
              let calendar = store.calendar(withIdentifier: calendarID) else {
            PunctualLogger.calendar.error("Event create failed: calendar not found")
            throw EventKitWriteError.calendarNotFound
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        Self.apply(draft, to: event)

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            PunctualLogger.calendar.error(
                "Event create save failed: \(String(describing: error), privacy: .private)"
            )
            throw error
        }
        return event.eventIdentifier
    }

    /// Re-fetches the event by identifier, applies `draft`, and saves.
    /// - Parameters:
    ///   - id: An event identifier or `calendarItemIdentifier` (`MBEvent.scriptIdentifier`).
    ///   - span: Scope of a recurring edit.
    func update(id: String, draft: EventDraft, span: EventEditSpan = .thisEvent) async throws {
        let store = EKEventStore.shared
        guard let event = Self.lookupEvent(id: id, in: store) else {
            PunctualLogger.calendar.error(
                "Event update failed: event not found for \(id, privacy: .private)"
            )
            throw EventKitWriteError.eventNotFound
        }

        if let calendarID = draft.calendarID,
           let calendar = store.calendar(withIdentifier: calendarID) {
            event.calendar = calendar
        }
        Self.apply(draft, to: event)

        do {
            try store.save(event, span: span.ekSpan, commit: true)
        } catch {
            PunctualLogger.calendar.error(
                "Event update save failed for \(id, privacy: .private): \(String(describing: error), privacy: .private)"
            )
            throw error
        }
    }

    /// Re-fetches the event by identifier and removes it; `span` scopes a recurring delete.
    func delete(id: String, span: EventEditSpan = .thisEvent) async throws {
        let store = EKEventStore.shared
        guard let event = Self.lookupEvent(id: id, in: store) else {
            PunctualLogger.calendar.error(
                "Event delete failed: event not found for \(id, privacy: .private)"
            )
            throw EventKitWriteError.eventNotFound
        }

        do {
            try store.remove(event, span: span.ekSpan, commit: true)
        } catch {
            PunctualLogger.calendar.error(
                "Event delete failed for \(id, privacy: .private): \(String(describing: error), privacy: .private)"
            )
            throw error
        }
    }

    // MARK: - Helpers

    /// Resolves an event identifier, falling back to a `calendarItemIdentifier` lookup.
    private static func lookupEvent(id: String, in store: EKEventStore) -> EKEvent? {
        if let event = store.event(withIdentifier: id) {
            return event
        }
        return store.calendarItem(withIdentifier: id) as? EKEvent
    }

    private static func apply(_ draft: EventDraft, to event: EKEvent) {
        event.title = draft.title
        event.isAllDay = draft.isAllDay
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.location = draft.location.isEmpty ? nil : draft.location
        event.notes = draft.notes.isEmpty ? nil : draft.notes

        let trimmedURL = draft.url.trimmingCharacters(in: .whitespacesAndNewlines)
        event.url = trimmedURL.isEmpty ? nil : URL(string: trimmedURL)
    }
}
