//
//  EventReminderOverrides.swift
//  Punctual
//
//  Defaults storage for per-event start-reminder overrides. The planning logic lives in
//  `NotificationPlanner`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Defaults
import Foundation

/// One stored override, keyed on the per-occurrence `MBEvent.id`, so it affects a single
/// instance of a recurring event.
struct EventReminderOverride: Codable, Defaults.Serializable, Hashable {
    let id: String
    /// When the event ends, so the override can be pruned afterwards.
    let eventEndDate: Date
    /// Seconds before the start. `nil` means no reminder for this event at all.
    let offsetSeconds: Int?

    var planningOverride: StartReminderOverride {
        guard let offsetSeconds else { return .suppressed }
        return .offset(TimeInterval(offsetSeconds))
    }
}

enum EventReminderOverrideStore {
    /// The override for one event, or `nil` to follow the global setting.
    static func override(for id: String, in overrides: [EventReminderOverride]) -> StartReminderOverride? {
        overrides.first { $0.id == id }?.planningOverride
    }

    /// Drops overrides whose event has already ended.
    static func cleanupExpired(
        _ overrides: [EventReminderOverride],
        now: Date
    ) -> [EventReminderOverride] {
        overrides.filter { $0.eventEndDate.timeIntervalSince(now) > 0 }
    }

    // MARK: - Writes

    /// Sets or replaces the override for an event.
    @MainActor
    static func set(_ override: StartReminderOverride, for event: MBEvent) {
        let offsetSeconds: Int?
        switch override {
        case .suppressed: offsetSeconds = nil
        case .offset(let seconds): offsetSeconds = Int(seconds)
        }
        var stored = Defaults[.eventReminderOverrides].filter { $0.id != event.id }
        stored.append(EventReminderOverride(
            id: event.id,
            eventEndDate: event.endDate,
            offsetSeconds: offsetSeconds
        ))
        Defaults[.eventReminderOverrides] = stored
    }

    /// Returns the event to the global setting.
    @MainActor
    static func clear(for event: MBEvent) {
        Defaults[.eventReminderOverrides].removeAll { $0.id == event.id }
    }

    /// Prunes overrides for events that have ended.
    @MainActor
    static func pruneExpired(now: Date = Date()) {
        let current = Defaults[.eventReminderOverrides]
        let pruned = cleanupExpired(current, now: now)
        // Skip no-op writes, which would wake every Defaults observer.
        if pruned.count != current.count {
            Defaults[.eventReminderOverrides] = pruned
        }
    }
}
