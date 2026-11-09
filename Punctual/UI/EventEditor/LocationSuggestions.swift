//
//  LocationSuggestions.swift
//  Punctual
//
//  MapKit-backed location suggestions for the event editor.
//
//  MapKit sends the typed text to Apple, so the feature is off by default and gated by the
//  hostless `LocationAutocompletePolicy`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation
import MapKit

/// A single suggestion, flattened out of `MKLocalSearchCompletion` so the view never touches MapKit.
struct LocationSuggestion: Identifiable, Hashable {
    /// Composed from both lines: two different addresses can share a title.
    var id: String { "\(title)|\(subtitle)" }
    let title: String
    let subtitle: String

    /// The text placed in the location field when the suggestion is picked.
    var fieldValue: String {
        subtitle.isEmpty ? title : "\(title), \(subtitle)"
    }
}

@MainActor
final class LocationSuggestionsModel: NSObject, ObservableObject {
    @Published private(set) var suggestions: [LocationSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        // Not `.query`, which returns search phrases rather than places.
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Updates the suggestion list for `text`, or cancels and clears it when the policy says not to query.
    func update(for text: String, isEnabled: Bool) {
        guard LocationAutocompletePolicy.shouldQuery(text, isEnabled: isEnabled) else {
            // Cancel too, so a request already in flight cannot land after clearing.
            completer.cancel()
            if !suggestions.isEmpty { suggestions = [] }
            return
        }
        completer.queryFragment = text
    }

    /// Cancels any request and clears the suggestions.
    func clear() {
        completer.cancel()
        if !suggestions.isEmpty { suggestions = [] }
    }
}

extension LocationSuggestionsModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map {
            LocationSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
        Task { @MainActor [weak self] in
            // Capped to fit the editor sheet.
            self?.suggestions = Array(results.prefix(5))
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Failures are silent; the field still works as plain text.
        Task { @MainActor [weak self] in
            self?.suggestions = []
        }
    }
}
