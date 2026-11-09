//
//  CalendarSourceSelection+Punctual.swift
//  Punctual
//
//  Bridges `CalendarSourceKind` to the app layer's `EventStoreProvider` and
//  reports which sources this build can use.
//

import AppKit
import Defaults
import Foundation

extension CalendarSourceKind {
    init(provider: EventStoreProvider) {
        switch provider {
        case .macOSEventKit: self = .macOSEventKit
        case .googleCalendar: self = .googleCalendar
        }
    }

    var provider: EventStoreProvider {
        switch self {
        case .macOSEventKit: return .macOSEventKit
        case .googleCalendar: return .googleCalendar
        }
    }

    /// Whether the source can be signed into now. Google needs a shipped or user-supplied OAuth client.
    @MainActor
    var isAvailableInThisBuild: Bool {
        switch self {
        case .macOSEventKit: return true
        case .googleCalendar: return GoogleOAuthConfig.effectiveClient != nil
        }
    }
}

extension EventStoreProvider {
    var sourceKind: CalendarSourceKind { CalendarSourceKind(provider: self) }
}

extension CalendarSourceSelection {
    init(providers: [EventStoreProvider]) {
        self.init(enabled: providers.map(CalendarSourceKind.init(provider:)))
    }

    /// Enabled sources as app-layer providers, in display order.
    var providers: [EventStoreProvider] {
        enabled.map(\.provider)
    }

    func isEnabled(_ provider: EventStoreProvider) -> Bool {
        isEnabled(provider.sourceKind)
    }

    /// `selectedCalendarIDs(byProviderKey:)`, read from `Defaults`.
    static func connectedSelectedCalendarIDs() -> [String] {
        CalendarSourceSelection(providers: Defaults[.enabledCalendarSources])
            .selectedCalendarIDs(byProviderKey: Defaults[.selectedCalendarIDsByProvider])
    }

    /// The selection filtered down to what this build can actually reach.
    @MainActor
    var usable: CalendarSourceSelection {
        availableOnly(\.isAvailableInThisBuild)
    }
}
