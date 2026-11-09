//
//  EventSearch+Punctual.swift
//  Punctual
//
//  Maps `MBEvent` onto the pure `SearchableEvent` projection. App target only,
//  since it depends on `MBEvent`.
//

import Foundation

extension SearchableEvent {
    /// Projects an `MBEvent` for ranked search; `attendees` holds every attendee's and the organizer's name and email.
    init(event: MBEvent, sourceIndex: Int) {
        let attendeePeople = event.attendees.flatMap { [$0.name, $0.email].compactMap { $0 } }
        let organizerPeople = [event.organizer?.name, event.organizer?.email].compactMap { $0 }
        self.init(
            sourceIndex: sourceIndex,
            id: event.id,
            title: event.title,
            notes: event.notes,
            location: event.location,
            attendees: attendeePeople + organizerPeople
        )
    }
}
