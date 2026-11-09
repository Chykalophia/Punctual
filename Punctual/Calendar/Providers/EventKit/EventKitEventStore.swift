//
//  EventKitEventStore.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.06.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0.
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
import Defaults
import EventKit

// Ref: https://stackoverflow.com/a/66074963
extension EKParticipant {
    var safeNSURL: NSURL? {
        perform(#selector(getter: EKParticipant.url))?.takeUnretainedValue() as? NSURL
    }
}

extension EKEventStore: @unchecked @retroactive Sendable {}

extension EKEventStore: AuthenticatedEventStore {
    nonisolated(unsafe) static var shared = EKEventStore()

    public func signIn(forcePrompt: Bool = false) async throws {
        try await withCheckedThrowingContinuation { cont in
            let handler: @Sendable (Bool, (any Error)?) -> Void = { granted, error in
                if granted {
                    var sources = EKEventStore.shared.sources
                    sources.append(contentsOf: EKEventStore.shared.delegateSources)

                    EKEventStore.shared = EKEventStore(sources: sources)
                    cont.resume()
                } else { cont.resume(throwing: error ?? NSError(domain: "EKEventStore", code: 0)) }
            }

            if #available(macOS 14, *) {
                EKEventStore.shared.requestFullAccessToEvents(completion: handler)
            } else {
                EKEventStore.shared.requestAccess(to: .event, completion: handler)
            }
        }
    }

    public func signOut() async {}

    public func refreshSources() async {
        await Task.detached(priority: .userInitiated) {
            EKEventStore.shared.refreshSourcesIfNecessary()
        }.value
    }

    public func fetchAllCalendars() async throws -> [MBCalendar] {
        // Off the main thread: enumerating a large store blocks.
        await Task.detached(priority: .userInitiated) {
            EKEventStore.shared.calendars(for: .event).map { ekCalendar in
                MBCalendar(
                    title: ekCalendar.title,
                    id: ekCalendar.calendarIdentifier,
                    source: ekCalendar.source.title,
                    email: getGmailAccount(ekCalendar.source.description),
                    color: ekCalendar.color
                )
            }
        }.value
    }

    public func fetchEventsForDateRange(for calendars: [MBCalendar], from dateFrom: Date, to dateTo: Date) async throws -> [MBEvent] {
        // Off the main thread: `events(matching:)` blocks while EventKit walks the store.
        await Task.detached(priority: .userInitiated) {
            fetchEventsOffMain(knownCalendars: calendars, dateFrom: dateFrom, dateTo: dateTo)
        }.value
    }
}

private func fetchEventsOffMain(knownCalendars: [MBCalendar], dateFrom: Date, dateTo: Date) -> [MBEvent] {
    let selectedCalendars = EKEventStore.shared.calendars(for: .event).filter { knownCalendars.map(\.id).contains($0.calendarIdentifier) }

    if selectedCalendars.isEmpty {
        return []
    }

    let predicate = EKEventStore.shared.predicateForEvents(withStart: dateFrom, end: dateTo, calendars: selectedCalendars)
    let customRegexes = Defaults[.customRegexes]

    var events: [MBEvent] = []
    for rawEvent in EKEventStore.shared.events(matching: predicate) {
        guard let calendar = knownCalendars.first(where: { $0.id == rawEvent.calendar.calendarIdentifier }) else {
            PunctualLogger.calendar.warning(
                "Skipping EventKit event from unknown calendar \(rawEvent.calendar.calendarIdentifier, privacy: .private)"
            )
            continue
        }
        events.append(mbEvent(from: rawEvent, calendar: calendar, customRegexes: customRegexes))
    }
    let deduplicated = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
    return Array(deduplicated)
}

func mbEvent(from rawEvent: EKEvent, calendar: MBCalendar, customRegexes: [String]) -> MBEvent {
    var status: MBEventStatus
    switch rawEvent.status {
    case .confirmed:
        status = .confirmed
    case .tentative:
        status = .tentative
    case .canceled:
        status = .canceled
    default:
        status = .none
    }

    let organizer = MBEventOrganizer(email: rawEvent.organizer?.url.absoluteString, name: rawEvent.organizer?.name)

    var attendees: [MBEventAttendee] = []

    for rawAttendee in rawEvent.attendees ?? [] {
        if rawAttendee.participantType != .person {
            continue
        }
        var attendeeStatus: MBEventAttendeeStatus
        switch rawAttendee.participantStatus {
        case .pending:
            attendeeStatus = .pending
        case .accepted:
            attendeeStatus = .accepted
        case .declined:
            attendeeStatus = .declined
        case .tentative:
            attendeeStatus = .tentative
        case .delegated:
            attendeeStatus = .delegated
        case .completed:
            attendeeStatus = .completed
        case .inProcess:
            attendeeStatus = .inProcess
        default:
            attendeeStatus = .unknown
        }

        let optional = rawAttendee.participantRole == .optional
        let email = rawAttendee.safeNSURL?.resourceSpecifier
        let attendee = MBEventAttendee(email: email, name: rawAttendee.name, status: attendeeStatus, optional: optional, isCurrentUser: rawAttendee.isCurrentUser)

        attendees.append(attendee)
    }

    // EventKit shares calendarItemIdentifier across a recurring series, so the start
    // date is appended to make the id per-occurrence; scripts get the raw identifier.
    return MBEvent(
        id: "\(rawEvent.calendarItemIdentifier):\(Int(rawEvent.startDate.timeIntervalSince1970))",
        scriptIdentifier: rawEvent.calendarItemIdentifier,
        lastModifiedDate: rawEvent.lastModifiedDate,
        title: rawEvent.title,
        status: status,
        notes: rawEvent.notes,
        location: rawEvent.location,
        url: rawEvent.url,
        calendarOpenURL: eventKitCalendarOpenURL(for: rawEvent.calendarItemIdentifier),
        organizer: organizer,
        attendees: attendees,
        startDate: rawEvent.startDate,
        endDate: rawEvent.endDate,
        isAllDay: rawEvent.isAllDay,
        recurrent: rawEvent.hasRecurrenceRules,
        calendar: calendar,
        customRegexes: customRegexes,
        externalIdentifier: rawEvent.calendarItemExternalIdentifier
    )
}

func eventKitCalendarOpenURL(for identifier: String) -> URL? {
    URL(string: "ical://ekevent/\(identifier)")
}

func getGmailAccount(_ text: String) -> String? {
    // Parses EKSource's undocumented `description` text; fragile if Apple changes its format.
    // `[^"]` stops each capture at the first closing quote when several mailto: entries appear.
    guard let regex = try? NSRegularExpression(pattern: #""mailto:([^"@]+@[^"]+)""#) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges > 1,
          let captureRange = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[captureRange])
}
