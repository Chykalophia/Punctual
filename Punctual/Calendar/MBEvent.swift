//
//  MBEvent.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 09.04.2022.
//  Copyright © 2022 Andrii Leitsius. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0.
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import Foundation

public enum MBEventStatus: Int, Sendable {
    case none = 0
    case confirmed = 1
    case tentative = 2
    case canceled = 3
}

public struct MBEventOrganizer: Hashable, Sendable {
    let name: String
    let email: String?

    init(email: String? = nil, name: String?) {
        self.email = email
        self.name = name ?? email ?? "status_bar_submenu_attendees_no_name".loco()
    }
}

public enum MBEventAttendeeStatus: Int, Sendable {
    case unknown = 0
    case pending = 1
    case accepted = 2
    case declined = 3
    case tentative = 4
    case delegated = 5
    case completed = 6
    case inProcess = 7
}

public struct MBEventAttendee: Hashable, Sendable {
    public let name: String
    public let email: String?
    public let status: MBEventAttendeeStatus
    public var optional = false
    public let isCurrentUser: Bool

    init(email: String?, name: String? = nil, status: MBEventAttendeeStatus, optional: Bool = false, isCurrentUser: Bool = false) {
        self.email = email
        self.name = name ?? email ?? "status_bar_submenu_attendees_no_name".loco()
        self.status = status
        self.optional = optional
        self.isCurrentUser = isCurrentUser
    }
}

public struct MBEvent: Identifiable, Hashable, Sendable {
    public var id: String

    /// The colour to draw this event in: its own when set, otherwise its calendar's.
    /// Use this rather than `calendar.color`.
    public var displayColor: NSColor { color ?? calendar.color }

    /// Identifier handed to `meetingStart` AppleScripts. Defaults to `id`; EventKit
    /// sets the series-wide `calendarItemIdentifier` to keep user scripts' expected format.
    public let scriptIdentifier: String

    public let lastModifiedDate: Date?
    public let calendar: MBCalendar
    public let title: String
    public var status: MBEventStatus
    public var participationStatus: MBEventAttendeeStatus = .unknown
    public var meetingLink: MeetingLink?
    var meetingLinkCandidate: MeetingLinkCandidate?
    var alternateMeetingLinkCandidates: [MeetingLinkCandidate] = []
    public var organizer: MBEventOrganizer?
    public let url: URL?
    /// Structured meeting URL from the provider (Google's video `conferenceData` entry point).
    /// Takes precedence over links found in `url`, `location` or `notes`; always `nil` for EventKit.
    public let conferenceURL: URL?
    /// URL that opens this event in its source calendar app: `ical://ekevent/<id>` for EventKit,
    /// the web `htmlLink` for Google. `nil` hides "Open in Calendar".
    public let calendarOpenURL: URL?
    public let notes: String?
    public let location: String?
    /// A colour set on the event itself, overriding its calendar's. Google only; `nil` for EventKit.
    public let color: NSColor?
    public let startDate: Date
    public let endDate: Date
    public var isAllDay: Bool
    public let recurrent: Bool
    /// EventKit's `calendarItemExternalIdentifier`, shared by copies of one event across
    /// calendars and used for deduplication. `nil` for Google events.
    public let externalIdentifier: String?
    public var attendees: [MBEventAttendee] = []

    init(id: String,
         scriptIdentifier: String? = nil,
         lastModifiedDate: Date?,
         title: String?,
         status: MBEventStatus,
         notes: String?,
         location: String?,
         url: URL?,
         conferenceURL: URL? = nil,
         calendarOpenURL: URL? = nil,
         organizer: MBEventOrganizer?,
         attendees: [MBEventAttendee] = [],
         startDate: Date,
         endDate: Date,
         isAllDay: Bool,
         recurrent: Bool,
         calendar: MBCalendar,
         customRegexes: [String] = [],
         externalIdentifier: String? = nil,
         color: NSColor? = nil) {
        self.calendar = calendar
        self.color = color
        self.externalIdentifier = externalIdentifier
        self.id = id
        self.scriptIdentifier = scriptIdentifier ?? id
        self.lastModifiedDate = lastModifiedDate
        self.title = title ?? "status_bar_no_title".loco()
        self.status = status

        self.isAllDay = isAllDay
        if !isAllDay, startDate != endDate {
            // Treat events from midnight to midnight as an all-day event
            let startDateIsMidnight = Calendar.current.startOfDay(for: startDate) == startDate
            let endDateIsMidnight = Calendar.current.startOfDay(for: endDate) == endDate
            if startDateIsMidnight, endDateIsMidnight {
                self.isAllDay = true
            }
        }

        self.notes = notes
        self.location = location
        self.url = url
        self.conferenceURL = conferenceURL
        self.calendarOpenURL = calendarOpenURL

        self.organizer = organizer
        self.attendees = attendees
        self.startDate = startDate
        self.endDate = endDate
        self.recurrent = recurrent

        let currentUser = attendees.first(where: { $0.isCurrentUser })
        if let currentUser {
            participationStatus = currentUser.status
        }

        let meetingLinkCandidates = MeetingLinkDetector.allCandidates(
            conferenceURL: conferenceURL,
            location: location,
            eventURL: url,
            notes: notes,
            calendarEmail: calendar.email,
            currentUserEmail: currentUser?.email,
            customRegexes: customRegexes
        )
        meetingLinkCandidate = meetingLinkCandidates.first
        alternateMeetingLinkCandidates = Array(meetingLinkCandidates.dropFirst())
        if let meetingLinkCandidate {
            meetingLink = MeetingLink(service: meetingLinkCandidate.service, url: meetingLinkCandidate.url)
        }
    }

}
