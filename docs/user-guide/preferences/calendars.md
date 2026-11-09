# Calendars

> Where your meetings come from, and whether macOS is actually syncing them.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-calendars-dark.png">
  <img src="../images/app/preferences-calendars-light.png" alt="Calendars pane" width="720">
</picture>

## Sources

Turn on **Apple Calendar**, **Google Calendar**, or both. Apple Calendar reads whatever your Mac already syncs. Google Calendar connects directly and carries more per-meeting detail: conference links, attendee replies, and the full description. A meeting that arrives from both is shown once, using the Google copy. Your calendar choices are kept separately for each source, so turning one off doesn't lose them.

Each source shows its status (for example "refreshed 2 minutes ago") and a **Reconnect** button when Google needs you to sign in again.

### Use my own Google credentials

For people who'd rather use their own Google Cloud project: turn on **Use my own Google credentials**, create an OAuth client of type *Desktop app*, and paste its **Client ID** (and **Client secret**, if it has one). Changing this signs you out of Google. A malformed ID shows "That does not look like a Google client ID."

## Calendars to show

Only the ticked calendars' meetings appear anywhere in Punctual. Search the list, or use **All** and **None**. If macOS is blocking access you'll see **Grant calendar access** and **Open Calendar privacy settings** instead.

## Apple Reminders

Shows whether Punctual may read Reminders: **Allow Access…** asks macOS; once allowed, today's reminders can appear in the dropdown ([Dropdown](dropdown.md) decides whether they do). If macOS is blocking it, **Open Privacy Settings…**.

## Calendar isn't updating?

Punctual shows whatever the macOS Calendar app has already synced; account access and sync frequency are macOS's. This section shows **Newest change the app can see** (if it's hours old, macOS has probably stopped syncing), any error macOS reported, **Refresh now**, and **Open Internet Accounts**.

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Calendars to show** | Only these calendars' meetings appear anywhere in Punctual. | — |
| **Apple Reminders** | macOS asks you the first time. Today's reminders can then appear in the dropdown. | — |
| **Refresh now** |  | — |
| **Calendar isn't updating?** | Punctual shows whatever the macOS Calendar app has already synced. Account access, sync frequency and data freshness are macOS's to control, not Punctual's — so when meetings look outdated or missing, the fix is upstream: refresh here, or re-sign-in to the account in Internet Accounts. | — |
<!-- settings-table:end -->
