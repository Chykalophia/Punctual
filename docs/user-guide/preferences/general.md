# General

> The app itself: how it starts, how it reads time, and the way back to calm.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-general-dark.png">
  <img src="../images/app/preferences-general-light.png" alt="General pane" width="720">
</picture>

- **Open Punctual when I log in.**
- **Time format**: 12-hour (3:30 PM) or 24-hour (15:30).
- **Location autocomplete** in the event editor. Off by default; when on, what you type in Location is sent to Apple to look up places, and nothing is sent until you've typed three characters. It's the only thing Punctual sends off your Mac.
- **Keyboard shortcuts**: see [Keyboard shortcuts](../keyboard-shortcuts-and-automation.md).
- **Reset all settings…**

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Suggest locations as I type** | Off by default. When on, what you type in a meeting's Location field is sent to Apple to look up matching places — the only thing Punctual ever sends off your Mac. Nothing else about your calendar leaves the machine, and nothing is sent until you have typed at least three characters. | `locationAutocompleteEnabled` · `false` |
| **Open Punctual when I log in** |  | — |
| **Time format** | Used everywhere in the app — menu bar, dropdown, timeline, calendar window and alerts. | `timeFormat` · `.am_pm` |
| **Keyboard shortcuts** |  | — |
<!-- settings-table:end -->
