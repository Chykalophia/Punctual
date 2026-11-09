//
//  DateMarkers.swift
//  Punctual
//
//  User-defined markers for important days drawn on the month grids: the model,
//  its storage encoding, and the day-matching rule.
//
//  Markers store month/day/year components, not a `Date`, so they never shift across time zones.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// One marked day.
public struct DateMarker: Equatable, Sendable {
    /// 1–12.
    public let month: Int
    /// 1 to 31, not validated against the month (29 February matches nothing in a common year).
    public let day: Int
    /// `nil` means every year.
    public let year: Int?
    public let label: String

    public init(month: Int, day: Int, year: Int? = nil, label: String) {
        self.month = month
        self.day = day
        self.year = year
        self.label = label
    }

    public var repeatsAnnually: Bool { year == nil }
}

/// String encoding of markers for `Defaults`, one string per marker.
///
/// Format: `YYYY-MM-DD|label`, with `----` as the year of a repeating marker.
/// The label may contain `|`; only the first separator is split on.
public enum DateMarkerCodec {
    private static let separator: Character = "|"
    private static let repeatingYear = "----"

    public static func encode(_ marker: DateMarker) -> String {
        let year = marker.year.map { String(format: "%04d", $0) } ?? repeatingYear
        let date = String(format: "%@-%02d-%02d", year, marker.month, marker.day)
        return "\(date)\(separator)\(marker.label)"
    }

    public static func decode(_ raw: String) -> DateMarker? {
        guard let separatorIndex = raw.firstIndex(of: separator) else { return nil }
        let datePart = String(raw[raw.startIndex ..< separatorIndex])
        let label = String(raw[raw.index(after: separatorIndex)...])
        guard !label.isEmpty else { return nil }

        let fields = datePart.split(separator: "-", omittingEmptySubsequences: false)
        // "-----12-25" splits into ["", "", "", "", "12", "25"]; a real year gives
        // ["2026", "12", "25"]. Normalise by taking the last two as month/day.
        guard fields.count >= 3 else { return nil }
        guard let day = Int(fields[fields.count - 1]),
              let month = Int(fields[fields.count - 2]) else { return nil }
        guard (1 ... 12).contains(month), (1 ... 31).contains(day) else { return nil }

        let yearField = fields[0 ..< (fields.count - 2)].joined(separator: "-")
        let year = yearField == repeatingYear ? nil : Int(yearField)
        // Reject a corrupt year rather than treating it as repeating.
        if year == nil, yearField != repeatingYear { return nil }

        return DateMarker(month: month, day: day, year: year, label: label)
    }

    /// Decodes a stored list, silently dropping entries that do not parse.
    public static func decodeAll(_ raws: [String]) -> [DateMarker] {
        raws.compactMap(decode)
    }

    public static func encodeAll(_ markers: [DateMarker]) -> [String] {
        markers.map(encode)
    }
}

public enum DateMarkerPolicy {
    /// The markers falling on `date`, in the order they were stored.
    ///
    /// Dated markers match on year, month and day in `calendar`; repeating ones ignore the year.
    public static func markers(
        on date: Date,
        from markers: [DateMarker],
        calendar: Calendar
    ) -> [DateMarker] {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else { return [] }

        return markers.filter { marker in
            guard marker.month == month, marker.day == day else { return false }
            guard let markerYear = marker.year else { return true }
            return markerYear == year
        }
    }

    /// Whether `date` carries any marker.
    public static func hasMarker(
        on date: Date,
        from markers: [DateMarker],
        calendar: Calendar
    ) -> Bool {
        // Qualified: the `markers` parameter shadows the function of the same name.
        !DateMarkerPolicy.markers(on: date, from: markers, calendar: calendar).isEmpty
    }
}
