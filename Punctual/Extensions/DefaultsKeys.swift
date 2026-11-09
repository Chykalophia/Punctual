//
//  DefaultsKeys.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 12.06.2020.
//  Copyright © 2020 Andrii Leitsius. All rights reserved.
//
//  Modified for Punctual by Peter Krzyzek / Chykalophia, 2026.
//
@preconcurrency import Defaults
import Foundation

extension Defaults.Keys {
    // General
    static let appVersion = Key<String>("appVersion", default: "0.1.0")
    // Last version whose What's New was shown. `ChangelogResetMigration` clears values
    // inherited from upstream MeetingBar so the newer-version check can fire.
    static let lastRevisedVersionInChangelog = Key<String>(
        "lastRevisedVersionInChangelog", default: "0.0.0")
    static let changelogResetMigrated = Key<Bool>("changelogResetMigrated", default: false)

    /// Mirrors the primary source's selection only. For "is any calendar selected",
    /// use `CalendarSourceSelection.connectedSelectedCalendarIDs()`.
    static let selectedCalendarIDs = Key<[String]>("selectedCalendarIDs", default: [])
    static let selectedCalendarIDsByProvider = Key<[String: [String]]>(
        "selectedCalendarIDsByProvider",
        default: [:]
    )
    static let selectedCalendarIDsByProviderMigrated = Key<Bool>(
        "selectedCalendarIDsByProviderMigrated",
        default: false
    )
    static let timeFormatDefaultMigrated = Key<Bool>(
        "timeFormatDefaultMigrated",
        default: false
    )
    static let eventStoreProvider = Key<EventStoreProvider>(
        "eventStoreProvider", default: .macOSEventKit)

    /// Calendar sources connected at once. Supersedes `eventStoreProvider`, which is
    /// kept in sync for compatibility. Never persisted empty.
    static let enabledCalendarSources = Key<[EventStoreProvider]>(
        "enabledCalendarSources", default: [])
    static let enabledCalendarSourcesMigrated = Key<Bool>(
        "enabledCalendarSourcesMigrated", default: false)

    // MARK: Google OAuth: bring your own client
    // The client ID is not secret and lives in Defaults; the optional secret is
    // stored in the Keychain by `GoogleUserOAuthClientStore`.
    static let googleUseUserOAuthClient = Key<Bool>(
        "googleUseUserOAuthClient", default: false)
    static let googleUserOAuthClientID = Key<String>(
        "googleUserOAuthClientID", default: "")
    /// Client ID the stored OAuth tokens were issued to; on mismatch the tokens are discarded.
    static let googleTokenClientIdentity = Key<String>(
        "googleTokenClientIdentity", default: "")

    static let onboardingCompleted = Key<Bool>("onboardingCompleted", default: false)

    static let showEventsForPeriod = Key<ShowEventsForPeriod>(
        "showEventsForPeriod", default: .today)
    static let joinEventNotification = Key<Bool>("joinEventNotification", default: true)
    static let joinEventNotificationTime = Key<TimeBeforeEvent>(
        "joinEventNotificationTime", default: .atStart)

    static let endOfEventNotification = Key<Bool>("endOfEventNotification", default: true)
    static let endOfEventNotificationTime = Key<TimeBeforeEventEnd>(
        "endOfEventNotificationTime", default: .atEnd)

    static let fullscreenNotification = Key<Bool>("fullscreenNotification", default: false)
    static let fullscreenNotificationTime = Key<TimeBeforeEvent>(
        "fullscreenNotificationTime", default: .atStart)
    static let fullscreenNotificationsForEventsWithoutMeetingLink = Key<Bool>(
        "fullscreenNotificationsForEventsWithoutMeetingLink",
        default: false
    )
    static let processedEventsForFullscreenNotification = Key<[ProcessedEvent]>(
        "processedEventsForFullscreenNotification", default: [])

    static let preferredLanguage = Key<AppLanguage>("preferredLanguage", default: .system)

    // Status Bar Appearance
    static let eventTitleFormat = Key<EventTitleFormat>("eventTitleFormat", default: .show)
    static let eventTimeFormat = Key<EventTimeFormat>("eventTimeFormat", default: .show)

    static let eventTitleIconFormat = Key<EventTitleIconFormat>(
        "eventTitleIconFormat", default: .none)
    static let statusbarEventTitleLength = Key<Int>(
        "statusbarEventTitleLength", default: statusbarEventTitleLengthLimits.max)

    static let hideMeetingTitle = Key<Bool>("hideMeetingTitle", default: false)
    static let dismissedEvents = Key<[ProcessedEvent]>("dismissedEvents", default: [])

    /// Per-event start-reminder overrides, keyed by per-occurrence `MBEvent.id` and pruned
    /// once each event ends. See `EventReminderOverrideStore`.
    static let eventReminderOverrides = Key<[EventReminderOverride]>(
        "eventReminderOverrides", default: [])

    static let ongoingEventVisibility = Key<OngoingEventVisibility>(
        "ongoingEventVisibility", default: .showTenMinBeforeNext)

    // Composable menu bar
    // Ordered `MenuBarTokenKind` raw values; empty means the classic status-bar title.
    static let menuBarTokens = Key<[String]>("menuBarTokens", default: [])
    static let menuBarCountdownStyle = Key<String>(
        "menuBarCountdownStyle", default: CountdownStyle.full.rawValue)
    // Minutes before start at which the Countdown block appears; 0 means no limit.
    static let menuBarCountdownLeadMinutes = Key<Int>("menuBarCountdownLeadMinutes", default: 0)
    static let menuBarDateStyle = Key<String>(
        "menuBarDateStyle", default: MenuBarDateStyle.medium.rawValue)
    static let menuBarProgressStyle = Key<String>(
        "menuBarProgressStyle", default: MenuBarProgressStyle.day.rawValue)
    // World-clock token time zone, stored as an identifier.
    static let menuBarWorldClockTimeZone = Key<String>(
        "menuBarWorldClockTimeZone", default: TimeZone.current.identifier)
    static let menuBarWorldClockLabel = Key<String>("menuBarWorldClockLabel", default: "")
    // Two-line menu bar layout: the meeting title on top, the other blocks beneath.
    static let menuBarTwoLineLayout = Key<Bool>("menuBarTwoLineLayout", default: false)
    // Set once `MenuBarTimeFormatDefaultsMigration` has run.
    static let menuBarTimeFormatMigrated = Key<Bool>(
        "menuBarTimeFormatMigrated",
        default: false
    )
    // Shows the Join chip, always rendered last. A toggle rather than a
    // `MenuBarTokenKind` so enabling it never rewrites stored block arrangements.
    static let menuBarShowJoinAction = Key<Bool>("menuBarShowJoinAction", default: true)
    // Minutes before start at which the Join chip appears; 0 means only while the
    // meeting runs. Independent of `eventActionHighlightMinutes`.
    static let menuBarJoinActionLeadMinutes = Key<Int>("menuBarJoinActionLeadMinutes", default: 2)

    // World-clock panel zones, as time-zone identifiers.
    static let worldClockPanelZones = Key<[String]>(
        "worldClockPanelZones", default: [TimeZone.current.identifier])

    // Dropdown greeting header. An empty name falls back to the user's full name.
    static let showGreetingInMenu = Key<Bool>("showGreetingInMenu", default: true)
    static let greetingName = Key<String>("greetingName", default: "")

    // Composable menu dropdown
    // Ordered `DropdownModule` raw values. `DropdownCompositionPolicy` re-appends any
    // missing modules in standard order.
    static let dropdownModuleOrder = Key<[String]>(
        "dropdownModuleOrder", default: DropdownComposition.standard.modules.map(\.rawValue))
    // Per-module enabled state. Greeting and timeline use `showGreetingInMenu` and
    // `showTimelineInMenu`.
    static let showMeetingControlInMenu = Key<Bool>("showMeetingControlInMenu", default: true)
    static let showAgendaInMenu = Key<Bool>("showAgendaInMenu", default: true)
    static let showJoinSectionInMenu = Key<Bool>("showJoinSectionInMenu", default: true)
    static let showBookmarksInMenu = Key<Bool>("showBookmarksInMenu", default: true)
    /// The compact month grid in the dropdown. Off by default: it is the tallest module.
    static let showCalendarInMenu = Key<Bool>("showCalendarInMenu", default: false)
    /// The up-next progress card module.
    static let showUpNextInMenu = Key<Bool>("showUpNextInMenu", default: true)

    // Calendar window month/week mode, as a `CalendarGridMode` raw value.
    static let calendarGridMode = Key<String>(
        "calendarGridMode", default: CalendarGridMode.month.rawValue)
    static let dimWeekendsInCalendar = Key<Bool>("dimWeekendsInCalendar", default: true)
    // 0 = follow the locale's first weekday; 1 = Sunday; 2 = Monday.
    static let calendarFirstWeekday = Key<Int>("calendarFirstWeekday", default: 0)
    static let showWeekNumbersInCalendar = Key<Bool>("showWeekNumbersInCalendar", default: false)
    static let maxEventsPerCalendarDay = Key<Int>("maxEventsPerCalendarDay", default: 3)

    // IDs of `PreferencesDisclosure` sections the user has expanded.
    static let preferencesExpandedDisclosures = Key<[String]>(
        "preferencesExpandedDisclosures", default: [])

    // Menu Appearance
    static let showTimelineInMenu = Key<Bool>("showTimelineInMenu", default: true)
    // When on, the menu's day list starts at "now" (hides finished events).
    static let hideFinishedEventsInMenu = Key<Bool>("hideFinishedEventsInMenu", default: true)
    // Whether menu event titles are truncated to `menuEventTitleLength` characters.
    static let shortenEventTitle = Key<Bool>("shortenEventTitle", default: true)
    static let menuEventTitleLength = Key<Int>("menuEventTitleLength", default: 50)

    static let showEventDetails = Key<Bool>("showEventDetails", default: false)
    static let showMeetingServiceIcon = Key<Bool>("showMeetingServiceIcon", default: true)
    static let showEventCalendarColor = Key<Bool>("showEventCalendarColor", default: true)

    // Shows meeting-prep links from the invite (docs, design files, repos) in event details.
    static let showMeetingPrepLinks = Key<Bool>("showMeetingPrepLinks", default: true)

    // Apple Reminders in the dropdown. Off by default; enabling it requests Reminders access.
    static let showRemindersInMenu = Key<Bool>("showRemindersInMenu", default: false)
    static let remindersIncludeOverdue = Key<Bool>("remindersIncludeOverdue", default: true)

    // Collapses copies of one event across calendars, accounts, or duplicate EventKit entries.
    static let deduplicateEvents = Key<Bool>("deduplicateEvents", default: true)

    static let declinedEventsAppereance = Key<DeclinedEventsAppereance>(
        "declinedEventsAppereance", default: .strikethrough)
    static let pastEventsAppereance = Key<PastEventsAppereance>(
        "pastEventsAppereance", default: .show_inactive)
    static let personalEventsAppereance = Key<PastEventsAppereance>(
        "personalEventsAppereance", default: .show_active)

    static let showEventMaxTimeUntilEventThreshold = Key<Int>(
        "showEventMaxTimeUntilEventThreshold", default: 60)
    static let showEventMaxTimeUntilEventEnabled = Key<Bool>(
        "showEventMaxTimeUntilEventEnabled", default: false)

    /// Minutes before a meeting at which its row action renders at full strength;
    /// muted before that.
    static let eventActionHighlightMinutes = Key<Int>(
        "eventActionHighlightMinutes", default: 2)

    /// Meeting rows per agenda section before a "+N more" row; 0 disables the cap.
    static let dropdownMaxEventRows = Key<Int>("dropdownMaxEventRows", default: 10)

    /// Whether the menu bar title uses a heavier weight within `eventActionHighlightMinutes`.
    static let menuBarHighlightImminentEvent = Key<Bool>(
        "menuBarHighlightImminentEvent", default: true)

    /// Dropdown row density, as a `DropdownDensity` raw value (the hostless enum can't
    /// import Defaults). Unknown values fall back to `.standard`.
    static let dropdownDensity = Key<String>(
        "dropdownDensity", default: DropdownDensity.standard.rawValue)

    /// Dropdown panel appearance and accent, as raw values; unknown values fall back to `.system`.
    static let panelAppearance = Key<String>(
        "panelAppearance", default: PanelAppearance.system.rawValue)
    static let panelAccent = Key<String>(
        "panelAccent", default: PanelAccent.system.rawValue)

    /// Whether the dropdown's month calendar folds to the current week. Independent of
    /// the calendar window's `calendarGridMode`.
    static let dropdownCalendarWeekFold = Key<Bool>("dropdownCalendarWeekFold", default: false)

    /// Whether the event editor suggests locations as you type. Must default to off:
    /// MapKit sends the typed text to Apple, the app's only off-device request.
    static let locationAutocompleteEnabled = Key<Bool>(
        "locationAutocompleteEnabled", default: false)

    /// User-marked important days, one `YYYY-MM-DD|label` string each (`----` for a
    /// repeating year). Parsed by `DateMarkerCodec`; a bad entry drops only that marker.
    static let dateMarkers = Key<[String]>("dateMarkers", default: [])

    /// Whether an empty look-ahead day is dropped from the agenda. Today is never hidden.
    static let dropdownHidesEmptyDays = Key<Bool>("dropdownHidesEmptyDays", default: false)

    /// Whether the greeting's second line shows today's date; when it does, the agenda's
    /// Today heading omits it.
    static let greetingShowsDate = Key<Bool>("greetingShowsDate", default: true)

    /// Meeting card fields, toggled individually; see `MeetingCardFields`.
    static let meetingCardShowsSectionLine = Key<Bool>(
        "meetingCardShowsSectionLine", default: true)
    static let meetingCardShowsTimes = Key<Bool>("meetingCardShowsTimes", default: true)
    static let meetingCardShowsProvider = Key<Bool>("meetingCardShowsProvider", default: true)
    static let meetingCardShowsSource = Key<Bool>("meetingCardShowsSource", default: true)

    /// Whether the dropdown's meeting card shows a countdown bar. Seeded from
    /// `showUpNextInMenu` by `DropdownModuleMergeMigration`.
    static let meetingCardShowsProgress = Key<Bool>(
        "meetingCardShowsProgress", default: true)

    /// Set once `DropdownModuleMergeMigration` has run. A flag because "off" is a valid result.
    static let dropdownModuleMergeMigrated = Key<Bool>(
        "dropdownModuleMergeMigrated", default: false)

    /// How the timeline is drawn (track, bar, or minimal), as a `TimelineAppearance` raw value.
    static let timelineAppearance = Key<String>(
        "timelineAppearance", default: TimelineAppearance.track.rawValue)

    /// The time span the timeline covers, as a `TimelineSpan` raw value; `off` hides it.
    /// Stored as "timelineStyle" for compatibility; do not rename.
    static let timelineStyle = Key<String>(
        "timelineStyle", default: TimelineSpan.relative.rawValue)

    /// How the menu bar draws progress toward the next meeting, as a `MeetingProgressStyle`
    /// raw value. Defaults to `.none`.
    static let meetingProgressStyle = Key<String>(
        "meetingProgressStyle", default: MeetingProgressStyle.none.rawValue)

    // How pending events appear in the status bar and menu.
    static let showPendingEvents = Key<PendingEventsAppereance>(
        "showPendingEvents", default: PendingEventsAppereance.show)

    // How tentative events appear.
    static let showTentativeEvents = Key<TentativeEventsAppereance>(
        "showTentativeEvents", default: TentativeEventsAppereance.show)

    // New installs default to 12-hour; `TimeFormatDefaultMigration` keeps existing
    // installs on 24-hour.
    static let timeFormat = Key<TimeFormat>("timeFormat", default: .am_pm)

    // Bookmarks
    static let bookmarks = Key<[Bookmark]>("bookmarks", default: [])

    // Configured browsers.
    static let browsers = Key<[Browser]>("browsers", default: [])

    // Default browser for meeting links.
    static let defaultBrowser = Key<Browser>(
        "defaultBrowser",
        default: Browser(name: "Default Browser", path: "", arguments: "", deletable: false))

    // Which all-day events are shown.
    static let allDayEvents = Key<AlldayEventsAppereance>(
        "allDayEvents", default: AlldayEventsAppereance.show)

    // Which timed events are shown.
    static let nonAllDayEvents = Key<NonAlldayEventsAppereance>(
        "nonAllDayEvents", default: NonAlldayEventsAppereance.show)

    // Whether each event entry shows its end time.
    static let showEventEndTime = Key<Bool>("showEventEndTime", default: true)

    // Integrations
    static let createMeetingService = Key<CreateMeetingServices>(
        "createMeetingService", default: .zoom)

    // Custom URL used to create meetings.
    static let createMeetingServiceUrl = Key<String>("createMeetingServiceUrl", default: "")

    static let meetBrowser = Key<Browser>("meetBrowser", default: systemDefaultBrowser)
    static let zoomBrowser = Key<Browser>("zoomBrowser", default: systemDefaultBrowser)
    static let teamsBrowser = Key<Browser>("teamsBrowser", default: systemDefaultBrowser)
    static let jitsiBrowser = Key<Browser>("jitsiBrowser", default: systemDefaultBrowser)
    static let slackBrowser = Key<Browser>("slackBrowser", default: systemDefaultBrowser)
    static let riversideBrowser = Key<Browser>("riversideBrowser", default: systemDefaultBrowser)

    /// Browser per meeting provider, keyed by `MeetingProvider.id`. Replaces the
    /// per-service `*Browser` keys above, which remain for `MeetingOpenPreferencesMigration`.
    static let providerBrowsers = Key<[String: Browser]>("providerBrowsers", default: [:])

    /// Per-provider opening mode IDs (app, web, PWA); unknown values fall back to the browser.
    static let providerOpeningModes = Key<[String: String]>("providerOpeningModes", default: [:])

    /// Browser used to create a new meeting.
    static let browserForCreateMeeting = Key<Browser>(
        "browserForCreateMeeting", default: systemDefaultBrowser)

    // Advanced
    static let automaticEventJoin = Key<Bool>("automaticEventJoin", default: false)
    static let automaticEventJoinTime = Key<TimeBeforeEvent>(
        "automaticEventJoinTime", default: .atStart)
    static let processedEventsForAutoJoin = Key<[ProcessedEvent]>(
        "processedEventsForAutoJoin", default: [])

    static let joinEventScriptLocation = Key<URL?>("joinEventScriptLocation", default: nil)
    static let runJoinEventScript = Key<Bool>("runAppleScriptWhenJoiningEvent", default: false)
    // Empty, not localized: a static `Key` default is evaluated before the app language
    // is resolved. `EditScriptModal` supplies the localized placeholder.
    static let joinEventScript = Key<String>("joinEventScript", default: "")

    static let eventStartScriptLocation = Key<URL?>("eventStartScriptLocation", default: nil)
    static let runEventStartScript = Key<Bool>("runEventStartScript", default: false)
    static let eventStartScriptTime = Key<TimeBeforeEvent>(
        "eventStartScriptTime", default: .atStart)
    static let eventStartScript = Key<String>(
        "eventStartScript", default: eventStartScriptPlaceholder)
    static let processedEventsForRunScriptOnEventStart = Key<[ProcessedEvent]>(
        "processedEventsForRunScriptOnEventStart", default: [])

    static let customRegexes = Key<[String]>("customRegexes", default: [])
    static let filterEventRegexes = Key<[String]>("filterEventRegexes", default: [])
}
