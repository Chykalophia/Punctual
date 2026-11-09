//
//  CalendarRepository.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.05.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
import Combine
import Defaults
import EventKit
import Foundation

// MARK: - Date range helpers

func calendarDateRange(for period: ShowEventsForPeriod) -> (from: Date, to: Date) {
    let dateFrom = Calendar.current.startOfDay(for: Date())
    let dateTo: Date
    switch period {
    case .today:
        dateTo = Calendar.current.date(byAdding: .day, value: 1, to: dateFrom)!
    case .today_n_tomorrow,
         .today_n_tomorrow_next,
         .today_n_tomorrow_summary:
        dateTo = Calendar.current.date(byAdding: .day, value: 2, to: dateFrom)!
    }
    return (dateFrom, dateTo)
}

enum CalendarRepositoryError: LocalizedError {
    case noCalendars(EventStoreProvider)
    /// Every connected source failed; carries the first underlying error.
    case allSourcesFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noCalendars(.googleCalendar):
            return "Google Calendar did not return any calendars"
        case .noCalendars(.macOSEventKit):
            return "macOS Calendar did not return any calendars"
        case let .allSourcesFailed(error):
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// The result of fetching across every connected source: what came back, and
/// which sources failed while others succeeded.
public struct CalendarFetchOutcome<Element> {
    public var elements: [Element]
    public var failures: [CalendarSourceFailure]
}

/// Owns the connected calendar providers and exposes calendar and event fetching.
@MainActor
public final class CalendarRepository {
    // MARK: - Connected sources

    /// Which sources are connected. Never empty.
    public private(set) var selection: CalendarSourceSelection

    /// The provider that handles writes and stands in wherever a single provider is required.
    /// EventKit whenever it is connected, as the only writable source.
    public var activeProviderName: EventStoreProvider {
        selection.writeSource?.provider ?? selection.providers.first ?? .macOSEventKit
    }

    /// The store behind `activeProviderName`.
    public var activeProvider: EventStore { store(for: activeProviderName) }

    /// Live stores, one per provider, created on demand.
    /// Kept after disconnect so reconnecting reuses the in-memory auth state.
    private var stores: [EventStoreProvider: EventStore] = [:]
    private let storeFactory: (EventStoreProvider) -> EventStore
    private let observesSystemStoreChanges: Bool
    private var pendingProvider: EventStore?

    /// Fires when the EKEventStore changes (macOS Calendar App only).
    let storeChanged = PassthroughSubject<Void, Never>()
    private var storeChangeCancellable: AnyCancellable?

    // MARK: - Initialization

    public init(selection: CalendarSourceSelection) {
        self.selection = selection
        self.storeFactory = CalendarRepository.makeStore(for:)
        self.observesSystemStoreChanges = true
        observeStoreChanges()
    }

    public convenience init(providerName: EventStoreProvider) {
        self.init(selection: CalendarSourceSelection(providers: [providerName]))
    }

    // MARK: - Source management

    /// Connects `providerName`, adding it to the connected set.
    ///
    /// The set changes only after sign-in and calendar listing succeed.
    /// - Parameter signOut: Forces a fresh sign-in, for re-authorizing a connected source.
    /// - Returns: Calendars from every connected source.
    @discardableResult
    public func connect(
        _ providerName: EventStoreProvider,
        signOut: Bool = false
    ) async throws -> [MBCalendar] {
        let candidate = store(for: providerName)
        pendingProvider = candidate
        defer { pendingProvider = nil }

        if signOut {
            await (candidate as? AuthenticatedEventStore)?.signOut()
        }

        try await (candidate as? AuthenticatedEventStore)?.signIn(forcePrompt: false)
        let calendars = try await candidate.fetchAllCalendars()
        if providerName == .googleCalendar, calendars.isEmpty {
            throw CalendarRepositoryError.noCalendars(providerName)
        }

        selection = selection.enabling(providerName.sourceKind)
        observeStoreChanges()
        return try await fetchAllCalendars().elements
    }

    /// Disconnects a source; a no-op for the last connected source.
    /// - Parameter signOut: Also discards the provider's stored credentials.
    public func disconnect(_ providerName: EventStoreProvider, signOut: Bool = false) async {
        guard selection.canDisable(providerName.sourceKind) else { return }
        selection = selection.disabling(providerName.sourceKind)

        if let store = stores[providerName] {
            if signOut {
                await (store as? AuthenticatedEventStore)?.signOut()
            }
            store.cancelPendingOperations()
        }
        observeStoreChanges()
    }

    /// Connects and disconnects sources as needed to reach `target`.
    public func applySelection(_ target: CalendarSourceSelection) async throws {
        for provider in selection.providers where !target.isEnabled(provider) {
            await disconnect(provider)
        }
        for provider in target.providers where !selection.isEnabled(provider) {
            try await connect(provider)
        }
    }

    public func stop() {
        storeChangeCancellable?.cancel()
        storeChangeCancellable = nil
        if let pendingProvider,
           !stores.values.contains(where: { $0 === pendingProvider }) {
            pendingProvider.cancelPendingOperations()
        }
        pendingProvider = nil
        for store in stores.values {
            store.cancelPendingOperations()
        }
    }

    // MARK: - Fetch

    /// Calendars from every connected source, merged in source display order.
    public func fetchAllCalendars() async throws -> CalendarFetchOutcome<MBCalendar> {
        try await gather { store, _ in try await store.fetchAllCalendars() }
    }

    public func fetchEventsForDateRange(
        for calendars: [MBCalendar],
        from dateFrom: Date,
        to dateTo: Date
    ) async throws -> CalendarFetchOutcome<MBEvent> {
        // Each store gets only its own calendars, and is called even with none.
        try await gather { store, provider in
            let owned = calendars.filter { $0.provider == provider }
            return try await store.fetchEventsForDateRange(for: owned, from: dateFrom, to: dateTo)
        }
    }

    /// The user's selected calendars out of `allCalendars`, across every connected source.
    ///
    /// Each calendar is matched against its own provider's selected IDs.
    public func selectedCalendars(from allCalendars: [MBCalendar]) -> [MBCalendar] {
        let selectedByProvider = Dictionary(
            uniqueKeysWithValues: selection.providers.map {
                ($0, Set(AppSettings.selectedCalendarIDs(for: $0)))
            }
        )
        return allCalendars.filter { calendar in
            selectedByProvider[calendar.provider]?.contains(calendar.id) ?? false
        }
    }

    /// Fetches events for the currently configured display period and selected
    /// calendars, across every connected source.
    public func fetchCurrentPeriodEvents(
        fromAllCalendars allCalendars: [MBCalendar]
    ) async throws -> CalendarFetchOutcome<MBEvent> {
        let (dateFrom, dateTo) = calendarDateRange(for: Defaults[.showEventsForPeriod])
        return try await fetchEventsForDateRange(
            for: selectedCalendars(from: allCalendars),
            from: dateFrom,
            to: dateTo
        )
    }

    public func refreshSources() async {
        for provider in selection.providers {
            await store(for: provider).refreshSources()
        }
    }

    /// Runs `work` against every connected source and merges the results.
    ///
    /// A source that throws is recorded in `failures` instead of aborting the fetch.
    /// - Throws: The provider's own error when the only source fails, otherwise
    ///   `CalendarRepositoryError.allSourcesFailed` when every source fails.
    ///
    /// Sources are awaited sequentially on purpose, to keep the merged order deterministic.
    private func gather<Element: Sendable>(
        _ work: (EventStore, EventStoreProvider) async throws -> [Element]
    ) async throws -> CalendarFetchOutcome<Element> {
        var elements: [Element] = []
        var failures: [CalendarSourceFailure] = []
        var firstError: Error?

        let providers = selection.providers
        for provider in providers {
            do {
                elements += try await work(store(for: provider), provider)
            } catch {
                if firstError == nil { firstError = error }
                failures.append(ProviderHealth.sourceFailure(provider: provider, error: error))
                let description = String(describing: error)
                PunctualLogger.calendar.error(
                    "Source \(provider.rawValue, privacy: .public) failed: \(description, privacy: .private)"
                )
            }
        }

        if failures.count == providers.count, let firstError {
            throw providers.count == 1
                ? firstError
                : CalendarRepositoryError.allSourcesFailed(firstError)
        }
        return CalendarFetchOutcome(elements: elements, failures: failures)
    }

    // MARK: - Authenticated helpers

    public func signIn(forcePrompt: Bool = false) async throws {
        try await (activeProvider as? AuthenticatedEventStore)?.signIn(forcePrompt: forcePrompt)
    }

    public func signOut() async {
        await (activeProvider as? AuthenticatedEventStore)?.signOut()
    }

    /// Forwards an OAuth callback URL to whichever store is mid-authorization.
    ///
    /// Returns `true` if the URL was consumed.
    @discardableResult
    public func resumeAuthorizationFlow(with url: URL) -> Bool {
        let candidates: [EventStore] = [pendingProvider].compactMap { $0 } + Array(stores.values)
        for candidate in candidates {
            guard let store = candidate as? GCEventStore,
                  let flow = store.currentAuthorizationFlow else { continue }
            if flow.resumeExternalUserAgentFlow(with: url) { return true }
        }
        return false
    }

    #if DEBUG
        /// Test-only: inject deterministic stores for source switching without
        /// creating EventKit/Google singletons.
        public convenience init(
            providerName: EventStoreProvider,
            storeFactory: @escaping (EventStoreProvider) -> EventStore
        ) {
            self.init(
                selection: CalendarSourceSelection(providers: [providerName]),
                storeFactory: storeFactory
            )
        }

        /// Test-only: start with several sources already connected, without calling `connect`.
        public init(
            selection: CalendarSourceSelection,
            storeFactory: @escaping (EventStoreProvider) -> EventStore
        ) {
            self.selection = selection
            self.storeFactory = storeFactory
            self.observesSystemStoreChanges = false
            // Created eagerly so `stop()` before the first fetch still cancels them.
            for provider in selection.providers {
                _ = store(for: provider)
            }
        }

        /// Test-only: inject a pre-built store without creating system singletons.
        public init(store: EventStore) {
            self.selection = CalendarSourceSelection(providers: [.macOSEventKit])
            self.storeFactory = { _ in store }
            self.observesSystemStoreChanges = false
            stores[.macOSEventKit] = store
        }
    #endif

    // MARK: - Private helpers

    /// Returns the live store for a provider, creating it on first use.
    private func store(for providerName: EventStoreProvider) -> EventStore {
        if let existing = stores[providerName] { return existing }
        let created = storeFactory(providerName)
        stores[providerName] = created
        return created
    }

    private static func makeStore(for providerName: EventStoreProvider) -> EventStore {
        switch providerName {
        case .macOSEventKit: return EKEventStore.shared
        case .googleCalendar: return GCEventStore.shared
        }
    }

    /// Watches EventKit for external changes while macOS Calendar is connected.
    /// Google has no push signal and relies on the periodic refresh.
    private func observeStoreChanges() {
        storeChangeCancellable?.cancel()
        storeChangeCancellable = nil
        guard observesSystemStoreChanges, selection.isEnabled(CalendarSourceKind.macOSEventKit) else { return }
        let store = EKEventStore.shared
        storeChangeCancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: store)
            .map { _ in () }
            .sink { [weak self] in self?.storeChanged.send() }
    }
}
