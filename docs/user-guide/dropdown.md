# The dropdown

Click Punctual in the menu bar to open the dropdown: a panel with your day at a glance.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/dropdown-dark.png">
  <img src="images/app/dropdown-light.png" alt="The dropdown" width="720">
</picture>

## Blocks

The dropdown is a stack of blocks you can reorder, configure, or hide in [Preferences ▸ Dropdown](preferences/dropdown.md), which also shows a live preview. **Settings & Quit** is always pinned to the bottom.

| Block | What it shows |
|---|---|
| Greeting | "Good morning, Peter · 3 meetings today · 4h 30m free". The name comes from your macOS account unless you set one. |
| Timeline | Today's meetings on a strip. Style: Track, Bar, or Minimal. Covers: around now, or the whole day. |
| Meeting card | The next (or current) meeting: time, service, Join button, and optional details. |
| Agenda | Today's meetings (and tomorrow's, depending on [Filters ▸ Look ahead](preferences/filters.md)). Reminders due today appear here when turned on. |
| Join & actions | Join current or next meeting, Create meeting, New event (⌘N), Search, and More actions. |
| Saved links | Standing rooms and phone numbers from [Joining ▸ My saved links](preferences/joining.md). |
| Month calendar | A compact month with dots on days that have meetings. Folds to a week. |

Ended meetings can be shown dimmed or hidden ([Filters](preferences/filters.md)):

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/dropdown-with-finished-dark.png">
  <img src="images/app/dropdown-with-finished-light.png" alt="The dropdown with an ended meeting shown" width="720">
</picture>

## Meeting rows

Click a meeting to expand its details. Depending on the meeting you'll see:

- Organizer, attendees and their replies (click an attendee to copy)
- **Remind me**: use the default, not for this meeting, when it starts, or N minutes before. This overrides [Alerts](preferences/alerts.md) for just this meeting.
- Copy meeting link, Copy room name, Copy meeting ID
- **Email attendees** (see [Emails](emails-and-web-pages.md#email-attendees))
- Dismiss meeting / Remove dismissal
- Edit… and Delete… (opens the [event editor](windows.md#event-editor))
- Join with other link, when an invite has more than one

## Reminders

With Apple Reminders allowed ([Calendars](preferences/calendars.md)) and shown ([Dropdown](preferences/dropdown.md)), reminders due today and overdue appear in a Reminders section. Each one can be **Completed**, **Snoozed** (Later today, This evening, Tomorrow), or **Opened in Reminders**. Changes write back to Apple Reminders.

## More actions

The More actions… flyout holds: Remove all dismissals, Open meeting from clipboard, Open calendar, Camera check…, World clock…, Dismiss next/current meeting, Hide/Show meeting title, What's new?, and Quit Punctual.

## Status messages

When something is wrong the dropdown says so in place of meetings, with a button to fix it:

| Message | Button |
|---|---|
| Google Calendar needs to be reconnected | Open Calendars in Preferences |
| Calendar permission is required | Open Calendars in Preferences |
| No calendars connected | Open Calendars in Preferences |
| No calendars selected | Select Calendars in Preferences |
| Calendar refresh failed | Refresh sources |
| No upcoming meetings | |
