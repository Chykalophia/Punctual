//
//  GoogleEventColors.swift
//  Punctual
//
//  Google's per-event colour palette, parsed from the `/colors` endpoint.
//  Fetched rather than hardcoded so colours track what Google Calendar shows.
//

import Foundation

/// Event `colorId` to background hex. Only the `event` palette is read; calendar
/// colours come from each calendarList entry's `backgroundColor`.
public struct GoogleColorPalette: Equatable, Sendable {
    /// Event `colorId` → background hex, e.g. `"11"` → `"#dc2127"`.
    public let eventBackgrounds: [String: String]

    public init(eventBackgrounds: [String: String]) {
        self.eventBackgrounds = eventBackgrounds
    }

    public static let empty = GoogleColorPalette(eventBackgrounds: [:])

    public var isEmpty: Bool { eventBackgrounds.isEmpty }

    /// The background hex for an event's `colorId`, or `nil` when absent or unknown.
    public func background(forEventColorID colorID: String?) -> String? {
        guard let colorID, !colorID.isEmpty else { return nil }
        return eventBackgrounds[colorID]
    }

    /// Parses the `/colors` response.
    ///
    /// ```
    /// { "kind": "calendar#colors",
    ///   "event": { "1": { "background": "#a4bdfc", "foreground": "#1d1d1d" } } }
    /// ```
    ///
    /// Entries without a valid hex background are dropped.
    public static func parse(_ json: [String: Any]) -> GoogleColorPalette {
        guard let event = json["event"] as? [String: Any] else { return .empty }

        var backgrounds: [String: String] = [:]
        for (colorID, value) in event {
            guard let entry = value as? [String: Any],
                  let background = entry["background"] as? String,
                  GoogleColorPalette.isHexColor(background)
            else { continue }
            backgrounds[colorID] = background
        }
        return GoogleColorPalette(eventBackgrounds: backgrounds)
    }

    /// Whether `value` is `#rrggbb` or `#rgb`.
    static func isHexColor(_ value: String) -> Bool {
        guard value.hasPrefix("#") else { return false }
        let digits = value.dropFirst()
        guard digits.count == 6 || digits.count == 3 else { return false }
        return digits.allSatisfy(\.isHexDigit)
    }
}
