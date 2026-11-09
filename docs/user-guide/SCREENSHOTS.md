# Regenerating the screenshots

Every image in this guide comes from code, so a UI change is one command away from fresh docs.

| Folder | What | How | Where it runs |
|---|---|---|---|
| `images/app/` | Every app window, Preferences pane, setup step and dropdown state, light and dark | `make docs-screenshots` | A Mac with Xcode |
| `images/web/` | The Google sign-in confirmation page, light and dark | `make docs-web-screenshots` | Anywhere with Node and Playwright |
| `images/manual/` | Things macOS draws, not Punctual: the menu-bar item, the right-click menu, notification banners, dialogs, camera check | `screencapture` on a Mac (below) | A Mac |
| `preferences/*.md` tables | Every setting, its help text, key and default | `make docs-settings` (CI runs `make docs-settings-check`) | Anywhere with Python 3 |

## App screenshots

`make docs-screenshots` runs `PunctualTests/DocsScreenshotTests`, which builds each window exactly as the app does and renders it against `PreviewFixtures` sample data with the clock pinned to 9:35 AM. Your own calendar is never read. The test is skipped in normal test runs; it only runs when `PUNCTUAL_DOCS_SCREENSHOT_DIR` is set, which the make target does.

Files it writes (each as `-light.png` and `-dark.png` unless noted):

- `preferences-{calendars,filters,menu-bar,dropdown,grid,joining,alerts,general,about}`, `preferences-search`
- `onboarding-{welcome,authorization,calendars,essentials,done}`
- `dropdown`, `dropdown-with-finished`
- `command-bar`, `calendar-window-month`, `calendar-window-week`, `event-editor-new`, `event-editor-edit`, `world-clock`, `whats-new`
- `fullscreen-notification.png` (dark only, as in the app)

A new window or pane needs a new test method there and a line in the matching page.

## Manual captures

These are drawn by macOS itself (status items, `NSMenu`, Notification Center, `NSAlert`) or need live hardware, so they can't be rendered offscreen. Capture them from the real app. In a Debug build, right-click the menu-bar item and choose **Debug harness…** to load synthetic meetings instead of your own; capture the right-click menu itself from a Release build so the debug item isn't in the shot. Then:

```sh
# a window or menu: press Space, then click it (-o drops the shadow)
screencapture -i -o docs/user-guide/images/manual/quick-actions-menu.png
```

| File | What to capture |
|---|---|
| `menu-bar-item.png` | The menu-bar item with a meeting and countdown (crop to the right side of the menu bar) |
| `quick-actions-menu.png` | The right-click menu |
| `notification-start.png` | A meeting-start banner, expanded to show its actions |
| `dialog-script-missing.png` | An in-app alert dialog |
| `camera-check.png` | The camera check window (use a neutral background) |

## Web page

`make docs-web-screenshots` reads the HTML straight out of `OAuthCompletionPage.swift`, fills in the English strings, and renders it in headless Chromium. Install Playwright once with `npm i -g playwright && npx playwright install chromium`.
