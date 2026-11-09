# Alerts

> When Punctual interrupts you.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-alerts-dark.png">
  <img src="../images/app/preferences-alerts-light.png" alt="Alerts pane" width="720">
</picture>

See [Notifications and alerts](../notifications-and-alerts.md) for what each one looks like.

- **Before a meeting starts**: Notify me (and how early); Take over the screen (fullscreen reminder), optionally for blocks with no meeting link.
- **Before a meeting ends**: Notify me, and how early.
- **Joining for you**: Open the meeting for me, without clicking (with **Change in Joining** to pick where).
- **Scripts**: Run a script before a meeting starts (**Test on my next meeting**, **Edit the before-meeting script…**) and Run a script the moment I click Join (**Edit the on-join script…**).

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Notify me before a meeting starts** |  | `joinEventNotification` · `true`<br>`joinEventNotificationTime` · `.atStart` |
| **Take over the screen before a meeting** | Those show a fullscreen reminder with a Dismiss button only. | `fullscreenNotification` · `false`<br>`fullscreenNotificationTime` · `.atStart`<br>`fullscreenNotificationsForEventsWithoutMeetingLink` · `false` |
| **Notify me before a meeting ends** |  | `endOfEventNotification` · `true`<br>`endOfEventNotificationTime` · `.atEnd` |
| **Open the meeting for me, without clicking** | Opens in whatever you picked on the Joining page. | `automaticEventJoin` · `false`<br>`automaticEventJoinTime` · `.atStart` |
| **Run a script around meetings** | Runs only for meetings that have a link. | `runEventStartScript` · `false`<br>`eventStartScriptTime` · `.atStart`<br>`runAppleScriptWhenJoiningEvent` · `false` |
<!-- settings-table:end -->
