//
//  WorldClockPanel.swift
//  Punctual
//
//  Hostless core for the multi-zone world-clock panel: each zone's local time
//  and its day offset from the reference zone.
//

import Foundation

/// A user-chosen zone: a time-zone identifier plus its display label.
struct WorldClockZone: Equatable {
    let identifier: String
    let label: String
}

/// A rendered panel row.
struct WorldClockEntry: Equatable {
    let label: String
    let time: String
    /// Whole-day offset from the reference zone's day: -1 yesterday, 0 today, +1 tomorrow.
    let dayOffset: Int
}

/// Formatters for the world-clock panel.
enum WorldClockPanelPolicy {
    /// One entry per zone, in order. An unresolvable identifier falls back to
    /// `referenceZone`.
    static func entries(
        zones: [WorldClockZone],
        now: Date,
        use24Hour: Bool,
        referenceZone: TimeZone,
        locale: Locale
    ) -> [WorldClockEntry] {
        zones.map { zone in
            let timeZone = TimeZone(identifier: zone.identifier) ?? referenceZone
            return WorldClockEntry(
                label: zone.label,
                time: timeText(now: now, timeZone: timeZone, use24Hour: use24Hour, locale: locale),
                dayOffset: dayOffset(
                    now: now, zone: timeZone, referenceZone: referenceZone, locale: locale
                )
            )
        }
    }

    /// The current time in `timeZone`, formatted like `MenuBarCompositionPolicy.clockText`.
    static func timeText(now: Date, timeZone: TimeZone, use24Hour: Bool, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(use24Hour ? "Hmm" : "hmma")
        return formatter.string(from: now)
    }

    /// Whole-day difference of `zone`'s calendar day from `referenceZone`'s at `now`.
    ///
    /// Compares each zone's civil date re-anchored to UTC midnight, so UTC offsets
    /// and DST do not affect the result.
    static func dayOffset(now: Date, zone: TimeZone, referenceZone: TimeZone, locale: Locale) -> Int {
        let referenceDay = civilDay(now: now, zone: referenceZone, locale: locale)
        let zoneDay = civilDay(now: now, zone: zone, locale: locale)
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? referenceZone
        utcCalendar.locale = locale
        return utcCalendar.dateComponents([.day], from: referenceDay, to: zoneDay).day ?? 0
    }

    /// The civil (year/month/day) of `now` as seen in `zone`, re-anchored to UTC
    /// midnight so day differences between zones become plain whole-day spans.
    private static func civilDay(now: Date, zone: TimeZone, locale: Locale) -> Date {
        var zoneCalendar = Calendar(identifier: .gregorian)
        zoneCalendar.timeZone = zone
        zoneCalendar.locale = locale
        let components = zoneCalendar.dateComponents([.year, .month, .day], from: now)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(identifier: "UTC") ?? zone
        utcCalendar.locale = locale
        return utcCalendar.date(
            from: DateComponents(year: components.year, month: components.month, day: components.day)
        ) ?? now
    }

    /// A default label from a time-zone identifier: its last path component with
    /// underscores as spaces, e.g. "America/Los_Angeles" becomes "Los Angeles".
    static func cityLabel(fromIdentifier identifier: String) -> String {
        let lastComponent = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return lastComponent.replacingOccurrences(of: "_", with: " ")
    }
}
