# Notifications and alerts

Punctual can interrupt you in five ways. All of them are set in [Preferences ▸ Alerts](preferences/alerts.md), and the per-meeting **Remind me** menu in the [dropdown](dropdown.md#meeting-rows) can change the start reminder for one meeting.

None of them fire for all-day events, cancelled meetings, meetings you declined, or meetings you dismissed.

## 1. Meeting starts (macOS notification)

On by default, at the meeting's start.

<img src="images/manual/notification-start.png" alt="A meeting-start notification" width="720">

| Part | Content |
|---|---|
| Title | The meeting title, or "Meeting" while titles are hidden |
| Body | Depends on timing: "The event starts soon", "The event starts in one minute", "…three minutes", "…five minutes" |
| Sound | Default system sound |
| Level | Time Sensitive, so it can break through a Focus that allows it |
| Actions | **Join**, **Dismiss**, **Snooze until start time**, **Snooze for 5 / 10 / 15 / 30 min** |

Clicking the notification itself joins the meeting. A snoozed reminder comes back with the same actions minus "Snooze until start time".

Settings: **Notify me before a meeting starts** and **How early** (when it starts, 1, 3, or 5 minutes before).

## 2. Meeting ends (macOS notification)

On by default, at the meeting's end. Title as above; body "The event ends soon", "The event ends in one minute", "…three minutes", or "…five minutes". No action buttons.

Settings: **Notify me before a meeting ends** and how early.

## 3. Fullscreen reminder

Off by default. Takes over the screen with the meeting's service icon, title, time, location, and **Dismiss** and **Join** buttons. It's always dark.

<img src="images/app/fullscreen-notification.png" alt="Fullscreen reminder" width="720">

Settings: **Take over the screen before a meeting**, how early, and **Include blocks with no meeting link** (those show Dismiss only).

## 4. Join automatically

Off by default. Opens the meeting at its start (or earlier) without a click, in the browser or app set in [Joining](preferences/joining.md). Nothing is shown on screen besides the meeting opening.

## 5. Scripts

Off by default. Two AppleScripts you write in Preferences:

- **Run a script before a meeting starts**, for meetings that have a link. **Test on my next meeting** runs it now.
- **Run a script the moment I click Join.**

Scripts are saved in `~/Library/Application Scripts/com.chykalophia.Punctual`. If the folder picker lands elsewhere you'll see "Wrong folder". If a script is turned on but none is saved, Alerts warns "This is on, but no script has been saved yet — so nothing runs."

## In-app messages

Punctual also tells you when something it tried didn't work. These appear as a macOS notification when notifications are allowed (banner or alert style), and otherwise as a dialog with an **OK** button. The two script errors are always dialogs.

| When | Title | Text |
|---|---|---|
| "Join next" with nothing left today | There are no upcoming meetings today | Woohoo! It's time to make cocoa |
| You dismiss a meeting | Dismissed *title* | You can remove dismissal from Quick Actions |
| You remove all dismissals | Removed all dismissals | All dismissed meetings are back in action |
| A meeting has no joinable link | Ouch! Can't join the *title* | Link not found, or your meeting service is not yet supported |
| The meeting's app isn't installed | Oops! Unable to open the link in the *app* | Ensure you have the *app* installed, or open such links in a web browser from the preferences instead. |
| The chosen browser can't open a link | Oops! Unable to open the link in *browser* | Ensure you have *browser* installed, or open such links in a web browser from the preferences instead. |
| Create meeting with a bad custom URL | Cannot create new meeting | Custom URL "*value*" missing or invalid. |
| Join from clipboard, no link | No valid URL | Clipboard has no meeting link, so the meeting cannot be started. |
| Join from clipboard, empty | Clipboard is empty | Clipboard has no content, so the meeting cannot be started. |
| The on-join script errors | AppleScript error | The error from macOS |
| The before-meeting script errors (dialog) | AppleScript execution failed | The script in *path* failed: *error* |
| The before-meeting script is missing (dialog) | AppleScript file not found | The eventStartScript.scpt file does not exist in *path*. |
| Google connected from Preferences | Google Account connected | *you@example.com* is connected |

<img src="images/manual/dialog-script-missing.png" alt="An in-app alert dialog" width="720">

## Software updates

Updates use [Sparkle](https://sparkle-project.org), so these dialogs are drawn by Sparkle rather than Punctual:

- **Check for updates automatically?** Asked once, after first-run setup is finished.
- **A new version is available**, with release notes and Install Update, Remind Me Later, and Skip This Version.
- **You're up to date**, after Check for Updates… when there's nothing new.

The switches are in [About & Support](preferences/about.md).

## If notifications don't appear

Check System Settings ▸ Notifications ▸ Punctual: allow notifications, and choose Banners or Alerts. With notifications off, the in-app messages above fall back to dialogs, but meeting reminders can't be shown at all. **Copy a report for support** in [About & Support](preferences/about.md) includes the notification permission state.
