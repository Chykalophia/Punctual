# Menu Bar

> What you see in the macOS menu bar all day.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-menu-bar-dark.png">
  <img src="../images/app/preferences-menu-bar-light.png" alt="Menu Bar pane" width="720">
</picture>

See [The menu bar](../menu-bar.md) for what each block looks like.

- **Layout**: Classic, Minimal, Agenda, Info, or Custom. A starting point; rearranging blocks switches it to Custom.
- **Blocks**: reorder with the arrows, configure with the gear. Icon, Meeting title, Countdown, Date, Clock, Progress bar, Week number, World clock.
- **Join button**: show a Join button in the menu bar from N minutes before a meeting.
- **Keep the menu bar quiet until a meeting is close**, within N minutes.
- **Bolden the meeting when it's about to start.**
- **Meeting progress**: Nothing, Underline, Ring around the icon, Capsule, or Mini bar.
- **Menu bar layout**: one line, or two lines with the title on top.

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Layout** | A starting point. Rearranging the blocks below switches this to Custom. | `menuBarTokens` · `[]` |
| **Blocks** | The pieces of the menu bar, left to right. Use the arrows to reorder, and the gear to configure each block. | `menuBarTokens` · `[]`<br>`menuBarTimeFormatMigrated` · `false` |
| **Which icon** |  | `eventTitleIconFormat` · `.none` |
| **Show** |  | `eventTitleFormat` · `.show` |
| **Shorten long titles** | Long meeting names are trimmed to this length in the menu bar. | `statusbarEventTitleLength` · `statusbarEventTitleLengthLimits.max` |
| **Menu bar layout** |  | `menuBarTwoLineLayout` · `false` |
| **Show a Join button in the menu bar** | Adds a Join button after everything else in the menu bar, for meetings that have a link. Clicking it joins straight away; clicking anywhere else on the item opens the dropdown as usual. | `menuBarShowJoinAction` · `true`<br>`menuBarJoinActionLeadMinutes` · `2` |
| **Keep the menu bar quiet until a meeting is close** | e.g. at 30m, a 2:00 meeting shows in the menu bar at 1:30 — before that the meeting drops out, leaving the icon and any date or clock blocks. | `showEventMaxTimeUntilEventEnabled` · `false`<br>`showEventMaxTimeUntilEventThreshold` · `60` |
| **Write the countdown as** |  | `menuBarCountdownStyle` · `CountdownStyle.full.rawValue` |
| **Start counting down** | e.g. at 60m, a meeting 3 hours away still shows its name, but no countdown until an hour before. A meeting in progress always counts down to its end. | `menuBarCountdownLeadMinutes` · `0` |
| **Write the date as** |  | `menuBarDateStyle` · `MenuBarDateStyle.medium.rawValue` |
| **Show the next meeting approaching as** | Fills over the hour before the meeting, is exactly full when it starts, then counts through it in red. Nothing is drawn when no meeting is close. | `meetingProgressStyle` · `MeetingProgressStyle.none.rawValue` |
| **The progress bar tracks** |  | `menuBarProgressStyle` · `MenuBarProgressStyle.day.rawValue` |
| **Time zone** |  | `menuBarWorldClockTimeZone` · `TimeZone.current.identifier`<br>`menuBarWorldClockLabel` · `""` |
<!-- settings-table:end -->
