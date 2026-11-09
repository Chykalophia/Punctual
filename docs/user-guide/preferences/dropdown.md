# Dropdown

> What you see when you click Punctual.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-dropdown-dark.png">
  <img src="../images/app/preferences-dropdown-light.png" alt="Dropdown pane" width="720">
</picture>

When the window is wide enough, the right side shows a live preview of the real dropdown that updates as you change settings. Narrow the window and the preview hides ("Widen this window to bring back the live preview").

- **Blocks**: Greeting, Timeline, Meeting card, Agenda, Join & actions, Saved links, Month calendar. Use the arrows to reorder, the gear to configure, the minus to hide, and **Add block** to bring one back. Settings & Quit is always pinned to the bottom.
- **Greeting**: optional name (defaults to your macOS account name).
- **Timeline style** (Track, Bar, Minimal) and **Timeline covers** (Around now, Whole day).
- **Row spacing**: Small, Medium, Large.
- **Appearance** and **Accent colour** for the panel.
- **Show at most** N meetings per day; a packed day ends with a "Show 12 more meetings" row.
- **Shorten long titles** to N characters.
- **Highlight a meeting's button when it starts within** N minutes; buttons further out stay muted.
- **Show reminders due today** (needs [Reminders access](calendars.md#apple-reminders)).

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Timeline style** | Track shows overlapping meetings stacked, with the hours above. Bar puts everything on one line with the hours beneath. Minimal is the line alone. | `timelineAppearance` · `TimelineAppearance.track.rawValue` |
| **Timeline covers** | Around now keeps the bar centred on what's near, widening only as far as your meetings reach. Whole day gives every meeting a fixed place from morning to evening. | `timelineStyle` · `TimelineSpan.relative.rawValue` |
| **Blocks** | The pieces of the dropdown, top to bottom. Use the arrows to reorder, the gear to configure a block, and the minus to hide it. Settings & Quit is always pinned at the bottom. | `dropdownModuleOrder` · `DropdownComposition.standard.modules.map(\.rawValue)`<br>`showGreetingInMenu` · `true`<br>`showTimelineInMenu` · `true`<br>`showMeetingControlInMenu` · `true`<br>`showAgendaInMenu` · `true`<br>`showJoinSectionInMenu` · `true`<br>`showBookmarksInMenu` · `true` |
| **Your name** | Used in the dropdown greeting, e.g. “Good morning, Alex”. | `greetingName` · `""` |
| **Show today's date in the greeting** | With this on, the agenda's Today heading drops its date — the day is named once, at the top, instead of twice. | `greetingShowsDate` · `true` |
| **Important days** | Mark birthdays, anniversaries, or deadlines. Marked days stand out in both month calendars, and hovering one shows what it is. | `dateMarkers` · `[]` |
| **Appearance** | Light or dark for the dropdown only, regardless of the rest of the system. System follows your Mac, including any schedule you have set. | `panelAppearance` · `PanelAppearance.system.rawValue` |
| **Accent colour** | Colours the Join buttons, today's date, marked days, and the countdown bar. System uses the accent colour from System Settings. | `panelAccent` · `PanelAccent.system.rawValue` |
| **Hide days with no meetings** | Drops the Tomorrow heading entirely when tomorrow is free, instead of showing it above a "nothing tomorrow" line. Today always stays, so a free day still says so. | `dropdownHidesEmptyDays` · `false` |
| **Show a countdown bar** | Fills over the hour before the meeting starts, then counts through it. Hidden while the meeting is further off than that. | `meetingCardShowsProgress` · `true` |
| **Show today's reminders** | Needs Reminders access, which you grant on the Calendars page. | `showRemindersInMenu` · `false`<br>`remindersIncludeOverdue` · `true` |
| **Show each meeting's end time** |  | `showEventEndTime` · `true` |
| **Show the Zoom / Teams / Meet logo** |  | `showMeetingServiceIcon` · `true` |
| **Show the calendar's colour dot** |  | `showEventCalendarColor` · `true` |
| **Show prep links (Figma, Docs, GitHub…)** |  | `showMeetingPrepLinks` · `true` |
| **Shorten long titles** | Long meeting names are trimmed to this length in the dropdown. | `shortenEventTitle` · `true`<br>`menuEventTitleLength` · `50` |
<!-- settings-table:end -->
