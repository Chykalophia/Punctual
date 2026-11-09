# The menu bar

Punctual's menu-bar item is the part you see all day. By default it shows an icon, your next meeting's title, and a countdown.

<img src="images/manual/menu-bar-item.png" alt="Punctual in the macOS menu bar" width="720">

## What it can show

The item is built from **blocks**, set in [Preferences ▸ Menu Bar](preferences/menu-bar.md). Start from a **Layout** preset (Classic, Minimal, Agenda, Info) and rearrange from there; any change switches the preset to Custom.

| Block | What it shows | Options |
|---|---|---|
| Icon | The Punctual glyph, a calendar, or the meeting's own app icon (for example Teams) | Which icon, or none |
| Meeting title | The next meeting's title, the word "Meeting", a dot, or nothing | Shorten long titles to N characters |
| Countdown | Time until the meeting starts, or until the current one ends | Style `2h`, `2h 30m` or `2:30`; start counting N minutes before |
| Date | Today's date | `Mon`, `Mon, Jul 17` or `7/17/26` |
| Clock | The current time | Follows [General ▸ Time format](preferences/general.md) |
| Progress bar | How far through the day or year you are, as `███▍░░░░` | Today or This year |
| Week number | The ISO week | |
| World clock | The time in one other zone, with a short label like "SF" | Time zone and label |

Other menu-bar options:

- **Join button**: a small Join chip appears next to the title from N minutes before a meeting until it ends. Clicking the chip joins; clicking anywhere else opens the dropdown.
- **Keep the menu bar quiet** until a meeting is within N minutes.
- **Bolden the meeting when it's about to start.**
- **Meeting progress**: show the next meeting approaching as an underline, a ring around the icon, a capsule, or a mini bar. It's drawn in the menu bar's own text colour so it reads on any wallpaper.
- **One line or two lines** (title on top).

## Clicking it

- **Left-click** opens the [dropdown](dropdown.md).
- **Right-click** opens the quick-actions menu below.

## Right-click menu

<img src="images/manual/quick-actions-menu.png" alt="The right-click quick-actions menu" width="720">

| Item | What it does |
|---|---|
| Join next meeting | Opens the next meeting's link |
| Create meeting | Starts a new call on the service set in [Joining](preferences/joining.md) |
| New event… | Opens the [event editor](windows.md#event-editor) |
| Copy today's agenda | Copies today's meetings as text |
| Open calendar | Opens the [calendar window](windows.md#calendar-window) |
| World clock… | Opens the [world clock](windows.md#world-clock) |
| Camera check… | Opens [camera check](windows.md#camera-check) |
| Refresh calendars | Re-reads your calendars now |
| Preferences… | Opens [Preferences](preferences/README.md) |
| Check for Updates… | Checks GitHub for a newer version |
| Quit Punctual | |

## Hiding the meeting title

Before screen-sharing, use **Hide meeting title** in the dropdown's More actions, or assign the **Hide the meeting title in the menu bar** [shortcut](keyboard-shortcuts-and-automation.md). Notifications also use "Meeting" instead of the title while it's hidden. It doesn't hide titles anywhere else: the dropdown, the calendar window, the fullscreen reminder, and the "Dismissed *title*" message still show them.
