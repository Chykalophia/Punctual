//
//  LocationAutocompletePolicy.swift
//  Punctual
//
//  Decides whether a location query may leave this Mac. MapKit sends typed text to
//  Apple, the app's only off-device request, so the gate is off by default and tested.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

public enum LocationAutocompletePolicy {
    /// Below this, a query is noise: one or two characters match half the world,
    /// and every keystroke is a separate network request.
    public static let minimumQueryLength = 3

    /// Whether `text` may be sent to the suggestion service.
    ///
    /// The enabled check runs first, so a disabled feature never examines the query.
    public static func shouldQuery(
        _ text: String,
        isEnabled: Bool,
        minimumLength: Int = minimumQueryLength
    ) -> Bool {
        guard isEnabled else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= minimumLength
    }

    /// Whether suggestions should be shown for the current field contents.
    ///
    /// Separate from `shouldQuery` so stale results disappear as soon as the field drops
    /// below the threshold.
    public static func shouldPresentResults(
        for text: String,
        isEnabled: Bool,
        resultCount: Int,
        minimumLength: Int = minimumQueryLength
    ) -> Bool {
        guard resultCount > 0 else { return false }
        return shouldQuery(text, isEnabled: isEnabled, minimumLength: minimumLength)
    }
}
