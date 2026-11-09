//
//  CalendarSync.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.05.2025.
//  Copyright © 2025 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
import Cocoa
import Combine
import Defaults
import Foundation
import UserNotifications

public enum CalendarSyncError: LocalizedError {
    case eventStoreNotAvailable
    case calendarAccessFailed(Error)
    case eventFetchFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .eventStoreNotAvailable:
            return "Event store is not available"
        case let .calendarAccessFailed(error), let .eventFetchFailed(error):
            return error.localizedDescription
        }
    }
}

public enum ProviderSelectionResult: Equatable {
    case success
    case cancelled
    case authRequired(String)
    case failed(String)
}

@MainActor
public class CalendarSync: ObservableObject {
    @Published public private(set) var calendars: [MBCalendar] = []
    @Published public private(set) var events: [MBEvent] = []
    @Published public private(set) var providerHealth = ProviderHealth()

    var repository: CalendarRepository
    private let refreshInterval: TimeInterval
    private var cancellables = Set<AnyCancellable>()
    /// The repository store-change subscription, replaced (not stacked) on each provider change.
    private var storeChangeCancellable: AnyCancellable?
    private var storeChangeRefreshTask: Task<Void, Never>?
    private var refreshCycleTask: Task<Void, Never>?
    private var providerGeneration = 0
    let refreshSubject = PassthroughSubject<Void, Never>()

    // MARK: - Initialization

    public init(refreshInterval: TimeInterval = 180) async {
        self.refreshInterval = refreshInterval
        AppSettings.migrateSelectedCalendarsByProviderIfNeeded()
        repository = CalendarRepository(selection: AppSettings.enabledCalendarSources())
        await configureProvider(Defaults[.eventStoreProvider])
        setupPublishers()
        refreshSubject.send() // initial load
    }

    /// Connects a source, adding it to the connected set.
    ///
    /// Connecting an already-connected source re-authorizes it.
    public func changeEventStoreProvider(
        _ newProvider: EventStoreProvider,
        withSignOut: Bool = false
    ) async -> ProviderSelectionResult {
        do {
            let newCalendars = try await repository.connect(newProvider, signOut: withSignOut)
            refreshCycleTask?.cancel()
            refreshCycleTask = nil
            AppSettings.setEnabledCalendarSources(repository.selection)
            providerGeneration += 1
            calendars = newCalendars
            events = []
            providerHealth = ProviderHealth()
            subscribeToRepositoryStoreChanges()
            refreshSubject.send()
            return .success
        } catch {
            let attempted = Date()
            let errorDescription = String(describing: error)
            PunctualLogger.calendar.error(
                "Provider switch sign-in failed: \(errorDescription, privacy: .private)"
            )
            providerHealth = ProviderHealth.failure(
                previous: providerHealth,
                attempted: attempted,
                error: error
            )
            return providerSelectionResult(for: error)
        }
    }

    /// Disconnects a source without touching the others; a no-op for the last connected source.
    /// Credentials are kept unless `withSignOut` is set.
    public func disconnectEventStoreProvider(
        _ provider: EventStoreProvider,
        withSignOut: Bool = false
    ) async {
        guard repository.selection.canDisable(provider.sourceKind) else { return }
        await repository.disconnect(provider, signOut: withSignOut)
        refreshCycleTask?.cancel()
        refreshCycleTask = nil
        AppSettings.setEnabledCalendarSources(repository.selection)
        providerGeneration += 1
        calendars = calendars.filter { $0.provider != provider }
        events = events.filter { $0.calendar.provider != provider }
        providerHealth = ProviderHealth()
        subscribeToRepositoryStoreChanges()
        refreshSubject.send()
    }

    private func providerSelectionResult(for error: Error) -> ProviderSelectionResult {
        if let authError = error as? AuthError {
            switch authError {
            case .cancelled:
                return .cancelled
            case .notSignedIn:
                return .authRequired(error.localizedDescription)
            case .refreshFailed:
                return .failed(error.localizedDescription)
            case .notConfigured:
                return .failed(error.localizedDescription)
            }
        }
        if case .unauthorized = error as? GoogleCalendarError {
            return .authRequired(error.localizedDescription)
        }
        return .failed(error.localizedDescription)
    }

    private func configureProvider(_ providerName: EventStoreProvider) async {
        subscribeToRepositoryStoreChanges()
    }

    private func subscribeToRepositoryStoreChanges() {
        storeChangeCancellable?.cancel()
        storeChangeCancellable = repository.storeChanged
            .sink { [weak self] in
                guard let self else { return }
                self.storeChangeRefreshTask?.cancel()
                self.storeChangeRefreshTask = Task { [weak self] in
                    do {
                        try await self?.refreshSources()
                    } catch {
                        let errorDescription = String(describing: error)
                        PunctualLogger.calendar.error(
                            "Calendar reload after store change failed: \(errorDescription, privacy: .private)"
                        )
                    }
                }
            }
    }

    public func stop() {
        forcedSyncTask?.cancel()
        forcedSyncTask = nil
        storeChangeRefreshTask?.cancel()
        storeChangeRefreshTask = nil
        refreshCycleTask?.cancel()
        refreshCycleTask = nil
        storeChangeCancellable?.cancel()
        storeChangeCancellable = nil
        cancellables.removeAll()
        repository.stop()
    }

    public func refreshSources() async throws {
        await repository.refreshSources()
        refreshSubject.send()
    }

    // MARK: - Aggressive force-sync

    /// Minimum seconds between forced syncs, so repeated menu-open, wake and unlock
    /// events do not hammer EventKit's `refreshSourcesIfNecessary()`.
    private static let forcedSyncDebounceInterval: TimeInterval = 30
    /// When the last forced sync was dispatched.
    private var lastForcedSyncAt: Date?
    private var forcedSyncTask: Task<Void, Never>?

    /// Asks the provider to sync its sources now, then re-fetches via `refreshSources()`.
    ///
    /// Debounced to one dispatch per `forcedSyncDebounceInterval`; the periodic timer
    /// and manual refresh are not debounced.
    public func forceSyncIfDebounceElapsed(now: Date = Date()) {
        if let lastForcedSyncAt,
           now.timeIntervalSince(lastForcedSyncAt) < Self.forcedSyncDebounceInterval {
            PunctualLogger.calendar.debug("Skipping forced calendar sync (debounced)")
            return
        }
        lastForcedSyncAt = now
        PunctualLogger.calendar.info("Forcing calendar sync (nudging provider to refresh sources)")
        forcedSyncTask?.cancel()
        forcedSyncTask = Task { [weak self] in
            do {
                try await self?.refreshSources()
            } catch {
                let errorDescription = String(describing: error)
                PunctualLogger.calendar.error(
                    "Forced calendar sync failed: \(errorDescription, privacy: .private)"
                )
            }
        }
    }

    /// Newest `lastModifiedDate` across the given events, or `nil` when none carry one.
    static func newestEventChange(in events: [MBEvent]) -> Date? {
        events.compactMap(\.lastModifiedDate).max()
    }

    /// Merges calendar-list and event-fetch failures, keeping one entry per provider.
    static func mergeFailures(
        _ first: [CalendarSourceFailure],
        _ second: [CalendarSourceFailure]
    ) -> [CalendarSourceFailure] {
        var seen = Set<EventStoreProvider>()
        return (first + second).filter { seen.insert($0.provider).inserted }
    }

    /// Fetches, deduplicates, filters and sorts events for the current period across every connected source.
    /// - Returns: The events plus any source that failed while another succeeded.
    private func fetchEvents(
        fromCalendars: [MBCalendar]
    ) async throws -> (events: [MBEvent], failures: [CalendarSourceFailure]) {
        let outcome: CalendarFetchOutcome<MBEvent>
        do {
            outcome = try await repository.fetchCurrentPeriodEvents(fromAllCalendars: fromCalendars)
        } catch {
            throw CalendarSyncError.eventFetchFailed(error)
        }
        let rawEvents = outcome.elements

        let deduplicatedEvents = Array(Dictionary(
            rawEvents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }
        ).values)

        // Cross-calendar and cross-source copies have distinct ids; collapse them by external
        // identifier. `sourcePriority` keeps the Google copy, which carries attendee status and conferencing.
        let events: [MBEvent]
        if Defaults[.deduplicateEvents] {
            let candidates = deduplicatedEvents.enumerated().map { index, event in
                DeduplicationEvent(
                    sourceIndex: index,
                    externalIdentifier: event.externalIdentifier,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    sourcePriority: event.calendar.provider.sourceKind.deduplicationPriority
                )
            }
            events = EventDeduplication.keptIndices(candidates).map { deduplicatedEvents[$0] }
        } else {
            events = deduplicatedEvents
        }

        if !AppSettings.current.events.dismissedEvents.isEmpty {
            AppSettings.refreshDismissedEvents(using: events)
        }
        EventReminderOverrideStore.pruneExpired()
        return (events.filtered().sorted { $0.startDate < $1.startDate }, outcome.failures)
    }

    private func setupPublishers() {
        // A) Defaults changes as an “empty” trigger
        let defaultsPub = Defaults.publisher(keys:
            .selectedCalendarIDs,
            // Drives fetching for every source; `selectedCalendarIDs` mirrors only the primary one.
            .selectedCalendarIDsByProvider,
            .enabledCalendarSources,
            .showEventsForPeriod,
            .customRegexes,
            .declinedEventsAppereance,
            .showPendingEvents,
            .showTentativeEvents,
            .allDayEvents,
            // Deduplication runs inside the fetch, so the toggle must trigger one.
            .deduplicateEvents,
            .nonAllDayEvents, options: []).map { _ in () }.eraseToAnyPublisher()

        // B) Periodic timer trigger
        let timerPub: AnyPublisher<Void, Never>
        if refreshInterval > 0 {
            timerPub = Timer
                .publish(every: refreshInterval, on: .main, in: .common)
                .autoconnect()
                .map { _ in () }
                .eraseToAnyPublisher()
        } else {
            timerPub = Empty().eraseToAnyPublisher()
        }

        // C) Manual trigger
        let manualPub = refreshSubject.eraseToAnyPublisher()

        // D) Merge all triggers. Throttle, not debounce: the first trigger fires
        // immediately and bursts collapse, where debounce would delay every refresh.
        let trigger = Publishers.Merge3(defaultsPub, timerPub, manualPub)
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: false)

        // E) Fetch calendars and events. `maxPublishers: .max(1)` runs one fetch at a time.
        trigger
            .flatMap(maxPublishers: .max(1)) { [weak self] _ -> AnyPublisher<RefreshResult, Never> in
                guard let self = self else {
                    return Just(
                        RefreshResult(
                            calendars: [],
                            events: [],
                            health: ProviderHealth(),
                            providerGeneration: -1
                        )
                    ).eraseToAnyPublisher()
                }
                // Republished on failure so the UI keeps the last known data.
                let preservedCalendars = self.calendars
                let preservedEvents = self.events
                let previousHealth = self.providerHealth
                let providerGeneration = self.providerGeneration
                return Deferred {
                    Future<RefreshResult, Never> { promise in
                        self.refreshCycleTask = Task { [weak self] in
                            guard let self else { return }
                            let attempted = Date()
                            do {
                                let calendarOutcome = try await self.repository.fetchAllCalendars()
                                try Task.checkCancellation()
                                let (evts, eventFailures) = try await self.fetchEvents(
                                    fromCalendars: calendarOutcome.elements
                                )
                                // Partial failures degrade health without discarding the sources that succeeded.
                                let health = ProviderHealth.success(
                                    attempted: attempted,
                                    lastSyncedChange: Self.newestEventChange(in: evts),
                                    degradedSources: Self.mergeFailures(
                                        calendarOutcome.failures, eventFailures
                                    )
                                )
                                promise(.success(RefreshResult(
                                    calendars: calendarOutcome.elements,
                                    events: evts,
                                    health: health,
                                    providerGeneration: providerGeneration
                                )))
                            } catch {
                                let errorDescription = String(describing: error)
                                PunctualLogger.calendar.error(
                                    "Event refresh failed: \(errorDescription, privacy: .private)"
                                )
                                let health = ProviderHealth.failure(
                                    previous: previousHealth,
                                    attempted: attempted,
                                    error: error
                                )
                                promise(.success(RefreshResult(
                                    calendars: preservedCalendars,
                                    events: preservedEvents,
                                    health: health,
                                    providerGeneration: providerGeneration
                                )))
                            }
                        }
                    }
                }
                .eraseToAnyPublisher()
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                guard let self,
                      result.providerGeneration == self.providerGeneration else {
                    return
                }
                self.calendars = result.calendars
                self.events = result.events
                self.providerHealth = result.health
            }
            .store(in: &cancellables)
    }

    /// Result of a single refresh cycle. On failure, `calendars` and `events`
    /// are the preserved last-known-good values so the UI keeps showing them.
    private struct RefreshResult {
        let calendars: [MBCalendar]
        let events: [MBEvent]
        let health: ProviderHealth
        let providerGeneration: Int
    }

    #if DEBUG
        /// Test-only initializer: inject your own store and skip
        /// the async system-store configuration.
        public init(provider: EventStore,
                    refreshInterval: TimeInterval = 0) {
            self.refreshInterval = refreshInterval
            self.repository = CalendarRepository(store: provider)
            AppSettings.recordEnabledCalendarSources(repository.selection)
            setupPublishers()
            refreshSubject.send()
        }

        /// Test-only initializer: inject a repository that can switch between
        /// deterministic fake providers.
        public init(repository: CalendarRepository,
                    refreshInterval: TimeInterval = 0) {
            self.refreshInterval = refreshInterval
            self.repository = repository
            // Records only the connected set, so selections the test set up are not re-derived.
            AppSettings.recordEnabledCalendarSources(repository.selection)
            subscribeToRepositoryStoreChanges()
            setupPublishers()
            refreshSubject.send()
        }
    #endif
}
