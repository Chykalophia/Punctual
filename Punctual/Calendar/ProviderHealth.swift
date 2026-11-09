//
//  ProviderHealth.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 24.04.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
import Foundation

/// One source failing while another succeeded, reported alongside a successful refresh.
public struct CalendarSourceFailure: Equatable, Sendable {
    public let provider: EventStoreProvider
    public let errorDescription: String
    public let authRequired: Bool

    public init(provider: EventStoreProvider, errorDescription: String, authRequired: Bool) {
        self.provider = provider
        self.errorDescription = errorDescription
        self.authRequired = authRequired
    }
}

public struct ProviderHealth: Equatable {
    public var lastSuccessfulRefresh: Date?
    public var lastAttemptedRefresh: Date?
    public var lastErrorDescription: String?
    /// True when the displayed data comes from a preserved snapshot, not the latest fetch attempt.
    public var isStale: Bool
    public var authRequired: Bool
    /// Sources that failed while at least one other succeeded.
    /// Always empty with one source; its failure goes to `lastErrorDescription`.
    public var degradedSources: [CalendarSourceFailure] = []
    /// Newest `MBEvent.lastModifiedDate` in the last fetched event set, shown as a staleness signal.
    /// EventKit has no "credentials expired" API, so a stalled macOS sync is only visible this way.
    public var lastSyncedChange: Date?

    public init(
        lastSuccessfulRefresh: Date? = nil,
        lastAttemptedRefresh: Date? = nil,
        lastErrorDescription: String? = nil,
        isStale: Bool = false,
        authRequired: Bool = false,
        lastSyncedChange: Date? = nil,
        degradedSources: [CalendarSourceFailure] = []
    ) {
        self.lastSuccessfulRefresh = lastSuccessfulRefresh
        self.lastAttemptedRefresh = lastAttemptedRefresh
        self.lastErrorDescription = lastErrorDescription
        self.isStale = isStale
        self.authRequired = authRequired
        self.lastSyncedChange = lastSyncedChange
        self.degradedSources = degradedSources
    }
}

extension ProviderHealth {
    static func success(
        attempted: Date,
        lastSyncedChange: Date? = nil,
        degradedSources: [CalendarSourceFailure] = []
    ) -> ProviderHealth {
        ProviderHealth(
            lastSuccessfulRefresh: attempted,
            lastAttemptedRefresh: attempted,
            lastErrorDescription: nil,
            isStale: false,
            authRequired: false,
            lastSyncedChange: lastSyncedChange,
            degradedSources: degradedSources
        )
    }

    /// Builds a partial failure from a source's error, using the same rules as a total failure.
    static func sourceFailure(provider: EventStoreProvider, error: Error) -> CalendarSourceFailure {
        CalendarSourceFailure(
            provider: provider,
            errorDescription: errorDescription(error),
            authRequired: isAuthRequired(error)
        )
    }

    static func failure(
        previous: ProviderHealth,
        attempted: Date,
        error: Error
    ) -> ProviderHealth {
        ProviderHealth(
            lastSuccessfulRefresh: previous.lastSuccessfulRefresh,
            lastAttemptedRefresh: attempted,
            lastErrorDescription: Self.errorDescription(error),
            isStale: true,
            authRequired: Self.isAuthRequired(error),
            lastSyncedChange: previous.lastSyncedChange
        )
    }

    private static func errorDescription(_ error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }
        return error.localizedDescription
    }

    private static func isAuthRequired(_ error: Error) -> Bool {
        if let authError = error as? AuthError {
            switch authError {
            case .notSignedIn:
                return true
            case .cancelled, .refreshFailed, .notConfigured:
                return false
            }
        }

        if let googleError = error as? GoogleCalendarError {
            switch googleError {
            case .unauthorized:
                return true
            case .forbiddenCalendar, .httpStatus, .missingItems:
                return false
            }
        }

        switch error {
        case let CalendarSyncError.calendarAccessFailed(underlying):
            return isAuthRequired(underlying)
        case let CalendarSyncError.eventFetchFailed(underlying):
            return isAuthRequired(underlying)
        default:
            return false
        }
    }
}
