# Getting started

## Install

Download the latest `Punctual-<version>.dmg` from the [GitHub releases page](https://github.com/Chykalophia/Punctual/releases), open it, and drag Punctual into Applications. Punctual is signed and notarized, and it keeps itself up to date (see [About & Support ▸ Updates](preferences/about.md)).

Punctual needs macOS 15 or later.

## First-run setup

The first time Punctual opens, a setup window walks you through four steps. A progress bar in the header shows where you are, and the ✕ closes setup. Closing it before the last step quits Punctual, and setup starts again on the next launch.

### 1. Welcome

Pick where your meetings come from: **Apple Calendar** (whatever your Mac already syncs, including iCloud, Google, and Exchange accounts added in System Settings) or **Google Calendar** directly.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/onboarding-welcome-dark.png">
  <img src="images/app/onboarding-welcome-light.png" alt="Setup step 1: Welcome" width="720">
</picture>

### 2. Verify calendar access

Punctual asks macOS for calendar access, or opens Google sign-in in your browser. While it waits you see "Waiting for authorization…". If access is denied or cancelled, you get **Back**, **System Preferences**, and **Try again** buttons.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/onboarding-authorization-dark.png">
  <img src="images/app/onboarding-authorization-light.png" alt="Setup step 2: Verify calendar access" width="720">
</picture>

When you connect Google, your browser shows a confirmation page. See [Emails and web pages](emails-and-web-pages.md#google-sign-in-confirmation-page).

### 3. Choose calendars

Tick the calendars whose meetings should appear. You need at least one to continue. If no calendars show, use **Refresh**, or **Open Calendar Settings** when macOS is blocking access.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/onboarding-calendars-dark.png">
  <img src="images/app/onboarding-calendars-light.png" alt="Setup step 3: Choose calendars" width="720">
</picture>

### 4. Choose daily behavior

A few defaults that matter from day one:

- **Open Punctual automatically when you log in**
- **New meetings use**: the service used by "Create meeting" (Zoom, Google Meet, Teams, and others)
- **Default browser for meeting links**
- **Send a system notification**, and how early (when it starts, or 1, 3, or 5 minutes before)

Everything here can be changed later in [Preferences](preferences/README.md).

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/onboarding-essentials-dark.png">
  <img src="images/app/onboarding-essentials-light.png" alt="Setup step 4: Choose daily behavior" width="720">
</picture>

### Done

"You're ready. Your next meeting will appear in the menu bar."

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="images/app/onboarding-done-dark.png">
  <img src="images/app/onboarding-done-light.png" alt="Setup complete" width="720">
</picture>

## Permissions Punctual asks for

| Permission | When it's asked | Why | Where to change it |
|---|---|---|---|
| Calendars | During setup (Apple Calendar source) | To read your meetings | System Settings ▸ Privacy & Security ▸ Calendars |
| Notifications | When Punctual first launches | Meeting reminders | System Settings ▸ Notifications ▸ Punctual |
| Reminders | Only when you click **Allow Access…** in [Calendars](preferences/calendars.md) | Today's reminders in the dropdown | System Settings ▸ Privacy & Security ▸ Reminders |
| Camera and microphone | Only when you open [Camera check](windows.md#camera-check) | Self-view before a call | System Settings ▸ Privacy & Security ▸ Camera / Microphone |

Punctual does not send your calendar anywhere. The two network features are opt-in or obvious: update checks against GitHub ([About & Support](preferences/about.md)) and location autocomplete in the event editor, which is off by default.
