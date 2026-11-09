//
//  CalendarSourceSelection.swift
//  Punctual
//
//  Pure model of which calendar sources are connected and the rules that keep the
//  set coherent. `CalendarSourceSelection+Punctual` bridges it to the app layer.
//

import Foundation

/// Host-independent mirror of the app layer's `EventStoreProvider`.
public enum CalendarSourceKind: String, Codable, Hashable, Sendable, CaseIterable {
    case macOSEventKit = "MacOS Calendar App"
    case googleCalendar = "Google Calendar API"

    /// Display order wherever sources are listed.
    public static let displayOrder: [CalendarSourceKind] = [.macOSEventKit, .googleCalendar]

    /// Which copy of a duplicated meeting survives; lower wins.
    ///
    /// Google wins (unlike display order) because its copy carries attendee status and
    /// conferencing data that EventKit's mirror lacks.
    public var deduplicationPriority: Int {
        switch self {
        case .googleCalendar: return 0
        case .macOSEventKit: return 1
        }
    }

    /// Localization key for the full source name, used by the source toggles and onboarding.
    public var titleKey: String {
        switch self {
        case .macOSEventKit: return "onboarding_apple_calendar_title"
        case .googleCalendar: return "onboarding_google_calendar_title"
        }
    }

    /// Localization key for the short source name, used beside an account heading.
    public var shortTitleKey: String {
        switch self {
        case .macOSEventKit: return "calendar_source_short_macos"
        case .googleCalendar: return "calendar_source_short_google"
        }
    }

    /// Whether this source can create, edit or delete events and reminders. Google is read-only.
    public var supportsWrites: Bool {
        switch self {
        case .macOSEventKit: return true
        case .googleCalendar: return false
        }
    }
}

/// The set of connected calendar sources, plus the rules that keep it coherent.
///
/// Always non-empty: an operation that would empty it is refused, and an empty
/// initializer input falls back to macOS Calendar.
public struct CalendarSourceSelection: Equatable, Sendable {
    /// Never empty, and always in `CalendarSourceKind.displayOrder`.
    public private(set) var enabled: [CalendarSourceKind]

    public init(enabled: [CalendarSourceKind]) {
        let normalized = Self.normalize(enabled)
        self.enabled = normalized.isEmpty ? [.macOSEventKit] : normalized
    }

    public func isEnabled(_ kind: CalendarSourceKind) -> Bool {
        enabled.contains(kind)
    }

    /// The connected source that handles writes, or nil when none can.
    public var writeSource: CalendarSourceKind? {
        enabled.first(where: \.supportsWrites)
    }

    /// Returns the selection with `kind` added; a no-op when already enabled.
    public func enabling(_ kind: CalendarSourceKind) -> CalendarSourceSelection {
        guard !isEnabled(kind) else { return self }
        return CalendarSourceSelection(enabled: enabled + [kind])
    }

    /// Returns the selection with `kind` removed; returns `self` unchanged for the last source.
    /// Use `canDisable(_:)` to disable the control instead.
    public func disabling(_ kind: CalendarSourceKind) -> CalendarSourceSelection {
        guard canDisable(kind) else { return self }
        return CalendarSourceSelection(enabled: enabled.filter { $0 != kind })
    }

    public func canDisable(_ kind: CalendarSourceKind) -> Bool {
        isEnabled(kind) && enabled.count > 1
    }

    public func setting(_ kind: CalendarSourceKind, enabled shouldEnable: Bool) -> CalendarSourceSelection {
        shouldEnable ? enabling(kind) : disabling(kind)
    }

    /// Drops sources this build cannot use, falling back to macOS Calendar if none remain.
    ///
    /// Apply on read, not write, so the stored selection survives until the source becomes available.
    public func availableOnly(_ isAvailable: (CalendarSourceKind) -> Bool) -> CalendarSourceSelection {
        let surviving = enabled.filter(isAvailable)
        return CalendarSourceSelection(enabled: surviving.isEmpty ? [.macOSEventKit] : surviving)
    }

    /// Calendar IDs ticked across the connected sources, in display order.
    /// Use this rather than the flat `selectedCalendarIDs` key, which mirrors only the primary source.
    public func selectedCalendarIDs(byProviderKey: [String: [String]]) -> [String] {
        enabled.flatMap { byProviderKey[$0.rawValue] ?? [] }
    }

    /// Selection for an install migrating from the single `eventStoreProvider` key.
    public static func migrating(fromSingleProvider provider: CalendarSourceKind) -> CalendarSourceSelection {
        CalendarSourceSelection(enabled: [provider])
    }

    /// Deduplicates and sorts into display order.
    private static func normalize(_ kinds: [CalendarSourceKind]) -> [CalendarSourceKind] {
        CalendarSourceKind.displayOrder.filter(kinds.contains)
    }
}
