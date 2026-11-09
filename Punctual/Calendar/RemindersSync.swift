//
//  RemindersSync.swift
//  Punctual
//
//  Publishes the reminders shown in the menu, refreshing on store changes,
//  settings changes, a timer and a manual subject.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Combine
import Defaults
import EventKit
import Foundation

@MainActor
final class RemindersSync: ObservableObject {
    @Published private(set) var reminders: [MBReminder] = []

    private let store: RemindersStore
    private let refreshInterval: TimeInterval
    let refreshSubject = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?

    init(store: RemindersStore, refreshInterval: TimeInterval = 180) {
        self.store = store
        self.refreshInterval = refreshInterval
        setupPublishers()
    }

    private func setupPublishers() {
        // A) External Reminders edits (Reminders.app, other devices via iCloud).
        let storeChangedPub = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .map { _ in () }
            .eraseToAnyPublisher()

        // B) Feature toggles that change what is shown.
        let defaultsPub = Defaults.publisher(
            keys: .showRemindersInMenu, .remindersIncludeOverdue, options: []
        )
        .map { _ in () }
        .eraseToAnyPublisher()

        // C) Periodic timer.
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

        // D) Manual trigger (startup, after a write).
        let manualPub = refreshSubject.eraseToAnyPublisher()

        Publishers.Merge4(storeChangedPub, defaultsPub, timerPub, manualPub)
            .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: false)
            .sink { [weak self] in self?.refresh() }
            .store(in: &cancellables)
    }

    /// Refreshes the published reminders, or clears them when the feature is off or access is not granted.
    func refresh() {
        guard Defaults[.showRemindersInMenu], store.isAccessGranted else {
            if !reminders.isEmpty { reminders = [] }
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            let fetched = await self.store.fetchDueToday()
            guard !Task.isCancelled else { return }
            self.reminders = fetched
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        cancellables.removeAll()
    }
}
