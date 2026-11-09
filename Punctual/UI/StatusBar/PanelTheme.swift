//
//  PanelTheme.swift
//  Punctual
//
//  Hostless dropdown panel theme: forced appearance and accent, with lenient
//  decoding. Deliberately limited to these two axes (see DROPDOWN-MODERNIZATION §1).
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// Which appearance the panel forces on itself.
public enum PanelAppearance: String, CaseIterable, Sendable {
    /// Follow the system (the default).
    case system
    case light
    case dark
}

/// Which accent the panel paints with: one of the macOS system accent colours.
public enum PanelAccent: String, CaseIterable, Sendable {
    /// Inherit the system accent (the default).
    case system
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case graphite

    /// Whether this overrides the system accent at all.
    public var overridesSystem: Bool { self != .system }
}

public enum PanelThemePolicy {
    /// Decodes a stored appearance, falling back to `.system` for unknown values.
    public static func appearance(fromRaw raw: String) -> PanelAppearance {
        PanelAppearance(rawValue: raw) ?? .system
    }

    /// Decodes a stored accent, falling back to `.system`.
    public static func accent(fromRaw raw: String) -> PanelAccent {
        PanelAccent(rawValue: raw) ?? .system
    }

    /// The appearance to force on the panel window.
    ///
    /// - Returns: `nil` for `.system`, meaning leave the window's appearance unset
    ///   so it keeps following live system changes.
    public static func forcedAppearance(_ appearance: PanelAppearance) -> PanelAppearance? {
        appearance == .system ? nil : appearance
    }
}
