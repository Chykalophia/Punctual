# Windows

Besides the menu bar and dropdown, Punctual has a few windows of its own. Each one can be opened from the right-click menu, the dropdown, or a [keyboard shortcut](keyboard-shortcuts-and-automation.md).

## Calendar window

Punctual's own month and week view (not Apple's Calendar app). Days with meetings get coloured dots, with a "+N" count when there are more than fit. Click a day to list its events; a meeting with a link shows **Join**.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/calendar-window-month-dark.png">
  <img src="images/app/calendar-window-month-light.png" alt="Calendar window, month view" width="720">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/calendar-window-week-dark.png">
  <img src="images/app/calendar-window-week-light.png" alt="Calendar window, week view" width="720">
</picture>

- ‹ › move by month or week, **Today** comes back, and the calendar icon opens **Jump to a date**.
- Arrow keys move the selected day.
- Settings: [Preferences ▸ Grid](preferences/grid.md) (open in month or week, first day of the week, week numbers, dimmed weekends, dots per day, important days).

## Search bar (command bar)

A Spotlight-style box for finding meetings and running actions. Open it with its shortcut or the search icon in the dropdown.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/command-bar-dark.png">
  <img src="images/app/command-bar-light.png" alt="The command bar" width="720">
</picture>

- Type part of a title, attendee, or location. Results are ranked and ignore case and accents.
- With nothing typed it shows actions (Join next meeting, Create meeting, Copy today's agenda, Refresh calendars, Open Preferences) and your upcoming meetings.
- ↑ ↓ to move, Return to run, Esc or click away to close.

## Event editor

Create, edit, or delete calendar events without leaving Punctual. This writes to your calendar through Apple Calendar, so it can only save to calendars macOS can see; a calendar that exists only through a directly connected Google account isn't offered.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/event-editor-new-dark.png">
  <img src="images/app/event-editor-new-light.png" alt="New Event" width="720">
</picture>

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/event-editor-edit-dark.png">
  <img src="images/app/event-editor-edit-light.png" alt="Edit Event" width="720">
</picture>

Fields: Title, All-day, Starts, Ends, Calendar, Location, URL, Notes. For a repeating event, **Apply to** chooses This event or This and future events. Delete asks for confirmation.

Validation messages: "Add a title for the event.", "The end time must be after the start time.", "Choose a calendar for the event."

Location autocomplete is off by default. Turn it on in [General](preferences/general.md); when on, what you type in Location is sent to Apple to look up places.

## World clock

A small window listing the current time in the zones you choose, marked Yesterday or Tomorrow when the date differs. **Edit** adds and removes zones.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/world-clock-dark.png">
  <img src="images/app/world-clock-light.png" alt="World Clock" width="720">
</picture>

## Camera check

Check your camera and microphone before a call: a live self-view, a microphone level meter, camera and microphone pickers, and **Join meeting**.

<img src="images/manual/camera-check.png" alt="Camera check" width="720">

It asks for camera and microphone access the first time. If there's no camera or access is denied, it says so and offers **Open System Settings**.

## What's New

Shown after an update, and from **What's New** in About & Support. It lists the current release first, then earlier releases.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/whats-new-dark.png">
  <img src="images/app/whats-new-light.png" alt="What's New in Punctual" width="720">
</picture>

## Preferences

See [Preferences](preferences/README.md).
