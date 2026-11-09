//
//  MeetingOpenPreferencesMigration.swift
//  MeetingBar
//
//  One-time migration from the per-provider browser keys (meetBrowser, zoomBrowser,
//  …) to the `providerBrowsers` map.
//

import Defaults
import Foundation

enum MeetingOpenPreferencesMigration {
    // MARK: - Pure migration logic (testable without Defaults)

    /// Builds a provider-browser map from legacy individual browser values.
    /// An entry is only written when `browser` differs from `systemDefault`,
    /// because the absent-key behaviour in strategies is already "use default browser".
    static func migrate(
        legacyValues: [(providerID: String, browser: Browser)],
        systemDefault: Browser
    ) -> [String: Browser] {
        var result: [String: Browser] = [:]
        for (id, browser) in legacyValues where browser != systemDefault {
            result[id] = browser
        }
        return result
    }

    // MARK: - Defaults-backed runner

    /// Reads the legacy per-provider browser keys and populates the unified
    /// `providerBrowsers` map. Skips if the map already has entries.
    static func migrateDefaultsIfNeeded() {
        guard Defaults[.providerBrowsers].isEmpty else { return }
        let legacy: [(String, Browser)] = [
            (MeetingServices.meet.rawValue, Defaults[.meetBrowser]),
            (MeetingServices.zoom.rawValue, Defaults[.zoomBrowser]),
            (MeetingServices.teams.rawValue, Defaults[.teamsBrowser]),
            (MeetingServices.jitsi.rawValue, Defaults[.jitsiBrowser]),
            (MeetingServices.slack.rawValue, Defaults[.slackBrowser]),
            (MeetingServices.riverside.rawValue, Defaults[.riversideBrowser])
        ]
        let migrated = migrate(legacyValues: legacy, systemDefault: systemDefaultBrowser)
        if !migrated.isEmpty {
            Defaults[.providerBrowsers] = migrated
        }
    }
}
