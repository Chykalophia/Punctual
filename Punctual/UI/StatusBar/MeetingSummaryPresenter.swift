//
//  MeetingSummaryPresenter.swift
//  Punctual
//
//  Turns an event into the copy the meeting card shows: section title, title,
//  metadata line, countdown.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// Which optional fields the meeting card shows. The title is always shown.
struct MeetingCardFields: Equatable, Sendable {
    /// The "Next meeting • in 2h" line above the title.
    var showsSectionLine = true
    /// The start/end range in the metadata line.
    var showsTimes = true
    /// The meeting service ("Google Meet", "Zoom").
    var showsProvider = true
    /// Which calendar and account the meeting came from.
    var showsSource = true

    static let all = MeetingCardFields()
}

enum MeetingSummaryPresenter {
    /// The meeting card's copy for `event`.
    ///
    /// - Parameter now: The panel's clock, used for current/next and the countdown.
    static func presentation(
        for event: MBEvent,
        timeFormat: TimeFormat,
        now: Date,
        fields: MeetingCardFields = .all
    ) -> MeetingSummaryPresentation {
        let isCurrent = event.startDate <= now && event.endDate > now
        let eventTitle = event.title.isEmpty
            ? "status_bar_no_title".loco()
            : event.title
        let time = timeStrings(for: event, timeFormat: timeFormat)
        let timeRange = event.isAllDay ? time.start : "\(time.start) – \(time.end)"
        let meetingProvider = fields.showsProvider
            ? event.meetingLink?.service.flatMap(MeetingProvider.provider(for:))?.displayName
            : nil
        let account = fields.showsSource
            ? firstMeaningfulValue([
                event.calendar.email,
                event.calendar.source == "unknown" ? nil : event.calendar.source,
                event.organizer?.email
            ])
            : nil

        let countdown: String?
        if !fields.showsSectionLine || isCurrent || event.isAllDay {
            countdown = nil
        } else {
            let timeLeft = StatusBarTitlePolicy.formattedTimeLeft(
                from: now,
                to: event.startDate,
                calendar: Calendar.current
            )
            countdown = timeLeft.isEmpty ? nil : "status_bar_event_status_in".loco(timeLeft)
        }

        return MeetingSummaryPresentation(
            // Empty string means "no section line"; the view omits it.
            sectionTitle: fields.showsSectionLine
                ? (isCurrent
                    ? "status_bar_control_current_meeting".loco()
                    : "status_bar_control_next_meeting".loco())
                : "",
            eventTitle: eventTitle,
            metadata: uniqueValues([
                fields.showsTimes ? timeRange : nil,
                meetingProvider,
                account,
                fields.showsSource ? event.calendar.title : nil
            ]),
            meetingService: event.meetingLink?.service,
            countdown: countdown
        )
    }

    /// Start and end in the user's time format. For an all-day event, start is
    /// the localized "All day" label and end is empty.
    static func timeStrings(
        for event: MBEvent,
        timeFormat: TimeFormat
    ) -> (start: String, end: String) {
        guard !event.isAllDay else {
            return ("status_bar_event_start_time_all_day".loco(), "")
        }

        let formatter = DateFormatter()
        formatter.locale = I18N.instance.locale
        switch timeFormat {
        case .am_pm: formatter.dateFormat = "h:mm a"
        case .military: formatter.dateFormat = "HH:mm"
        }
        return (
            formatter.string(from: event.startDate),
            formatter.string(from: event.endDate)
        )
    }

    /// The first non-empty value after trimming whitespace.
    static func firstMeaningfulValue(_ values: [String?]) -> String? {
        values.lazy
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    /// Non-empty trimmed values in order, without case- or diacritic-insensitive repeats.
    static func uniqueValues(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty
            else { return nil }
            let identity = trimmed.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(identity).inserted else { return nil }
            return trimmed
        }
    }
}
