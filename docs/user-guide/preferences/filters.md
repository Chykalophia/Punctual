# Filters

> The one place that decides which meetings exist — everywhere in the app.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-filters-dark.png">
  <img src="../images/app/preferences-filters-light.png" alt="Filters pane" width="720">
</picture>

These choices apply everywhere: menu bar, dropdown, calendar window, and notifications.

- **Look ahead**: Today; Today and tomorrow; Today, plus tomorrow's first event; or Today, plus a tomorrow summary.
- **Merge duplicates across calendars**: the same meeting on two calendars shows once.
- **Show me**: a preset for the list below, or **Pick them one by one**:
  - All-day entries (birthdays, OOO): Show, Only with a meeting link, Hide
  - Calendar blocks with no meeting link: Show, Dim, Hide
  - Blocks you booked for yourself (focus time, lunch): Show, Dim, Hide
  - Invites you haven't answered; Invites you answered Maybe: Show, Dim, Hide
  - Meetings you declined: Show (crossed out), Hide
  - Meetings that have ended: Show, Dim, Hide
- **Count the meeting happening now as "next"**: until the next one is close, for 10 minutes, or never.
- **Hide meetings whose title matches a pattern**, with **Try a title** to test your patterns.

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Look ahead** | Controls how much of tomorrow appears in the dropdown. “Today” means tomorrow's meetings are never loaded at all. | `showEventsForPeriod` · `.today` |
| **Merge duplicates across calendars** | One meeting invited to two of your calendars shows once, not twice. | `deduplicateEvents` · `true` |
| **All-day entries (birthdays, OOO)** |  | `allDayEvents` · `AlldayEventsAppereance.show` |
| **Calendar blocks with no meeting link** |  | `nonAllDayEvents` · `NonAlldayEventsAppereance.show` |
| **Blocks you booked for yourself (focus time, lunch)** |  | `personalEventsAppereance` · `.show_active` |
| **Invites you haven't answered** |  | `showPendingEvents` · `PendingEventsAppereance.show` |
| **Invites you answered Maybe** |  | `showTentativeEvents` · `TentativeEventsAppereance.show` |
| **Meetings you declined** |  | `declinedEventsAppereance` · `.strikethrough` |
| **Meetings that have ended** | Hide also drops them from the dropdown's list, so the day starts at now. | `pastEventsAppereance` · `.show_inactive`<br>`hideFinishedEventsInMenu` · `true` |
| **Count the meeting happening now as “next”** | e.g. at “For 10 minutes”, a 2:00 meeting stops being “next” at 2:10 and the 3:00 one takes over. | `ongoingEventVisibility` · `.showTenMinBeforeNext` |
| **Hide meetings whose title matches a pattern** | Matches the title only, not notes or location. | `filterEventRegexes` · `[]` |
<!-- settings-table:end -->
