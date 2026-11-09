# Preferences

Open Preferences from the right-click menu, the dropdown's gear, the command bar, or `punctual://preferences`.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-calendars-dark.png">
  <img src="../images/app/preferences-calendars-light.png" alt="The Preferences window" width="720">
</picture>

The sidebar lists eight panes, plus **About & Support** at the bottom. The search field at the top of the sidebar searches every setting by name, help text, and common synonyms (try "duplicate", "OOO", or "screen share"); click a result to jump to its pane.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-search-dark.png">
  <img src="../images/app/preferences-search-light.png" alt="Searching settings" width="720">
</picture>

Each pane ends with **Reset this section…**, which returns that pane to its defaults. **Reset all settings…** in General resets every pane. Neither touches your calendar choices, saved links, or browser setups.

| Pane | What it decides |
|---|---|
| [Calendars](calendars.md) | Where your meetings come from, and whether macOS is actually syncing them. |
| [Filters](filters.md) | The one place that decides which meetings exist, everywhere in the app. |
| [Menu Bar](menu-bar.md) | What you see in the macOS menu bar all day. |
| [Dropdown](dropdown.md) | What you see when you click Punctual. |
| [Grid](grid.md) | The month and week window Punctual opens, not Apple's Calendar app. |
| [Joining](joining.md) | What happens when you click Join, and where new meetings get created. |
| [Alerts](alerts.md) | When Punctual interrupts you. |
| [General](general.md) | The app itself: how it starts, how it reads time, and the way back to calm. |
| [About & Support](about.md) | Version, links, What's New, and a support report. |

Each pane page ends with a table of every setting, generated from the app's own settings index. The "Stored as" column is the `defaults` key, for people who script their setup (`defaults read com.chykalophia.Punctual <key>`).
