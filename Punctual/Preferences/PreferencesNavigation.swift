//
//  PreferencesNavigation.swift
//  Punctual
//
//  Lets a pane ask the Preferences window to show another pane. One-shot: the
//  window clears the request once it has switched.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Observation

@MainActor
@Observable
final class PreferencesNavigation {
    static let shared = PreferencesNavigation()

    /// The pane a control has asked the window to show, or `nil` when nothing is pending.
    var requestedTab: PreferencesTab?

    private init() {}

    func go(to tab: PreferencesTab) {
        requestedTab = tab
    }
}
