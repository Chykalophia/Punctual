# Grid

> The month and week window Punctual opens — not Apple's Calendar app.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-grid-dark.png">
  <img src="../images/app/preferences-grid-light.png" alt="Grid pane" width="720">
</picture>

Settings for the [calendar window](../windows.md#calendar-window).

- **Open in**: Month or Week. The window's own header still switches views.
- **First day of the week**: Auto (follow locale), Sunday, or Monday. Takes effect when you reopen the window.
- **Week numbers**: a thin column of ISO week numbers.
- **Dim weekends**: Saturdays and Sundays in lighter grey.
- **Event dots per day** before switching to a "+N more" count.
- **Important days**: mark birthdays, anniversaries, or deadlines. Marked days stand out in both month calendars, and hovering shows what they are.

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Dim weekends** | Saturdays and Sundays are drawn in lighter grey so the work week stands out. Today and the day you picked stay highlighted. | `dimWeekendsInCalendar` · `true` |
| **Open in** | The view the window starts in. Its own header still switches the view you are looking at now. | `calendarGridMode` · `CalendarGridMode.month.rawValue` |
| **First day of the week** | Auto follows your Mac's locale. Changing this takes effect when you reopen the calendar window. | `calendarFirstWeekday` · `0` |
| **Show week numbers** | A thin column of ISO week numbers on the left of the grid. | `showWeekNumbersInCalendar` · `false` |
| **Event dots per day** | How many coloured dots each day cell shows before switching to a "+N more" count. | `maxEventsPerCalendarDay` · `3` |
<!-- settings-table:end -->
