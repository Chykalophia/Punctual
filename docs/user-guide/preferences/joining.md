# Joining

> What happens when you click Join, and where new meetings get created.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../images/app/preferences-joining-dark.png">
  <img src="../images/app/preferences-joining-light.png" alt="Joining pane" width="720">
</picture>

- **Open meeting links in**: your default browser or one you pick. Meeting links open here unless a service is sent somewhere else below.
- **Per-service overrides**: for each meeting service (Zoom, Teams, Meet, and 50+ more), pick an app to open it natively, or a specific browser.
- **Set up browsers and apps…**: add custom browsers, browser profiles, or apps.
- **Creating meetings**: **New meetings use** (Zoom, Meet, Teams, a custom URL…), **Web address for new meetings** for custom URLs (tip: Google Meet supports `https://meet.google.com/new?authuser=1`), and **Open new meetings in**.
- **My saved links**: standing meeting rooms and phone numbers shown in the dropdown's Saved links block. **Add a link** asks for a name, a link or phone number, and a service.
- **Link patterns**: for invites whose link Punctual doesn't spot. **Test a pattern** against sample invite text.

## All settings on this pane

<!-- settings-table:begin -->
_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. Do not edit by hand._

| Setting | What it does | Stored as · default |
|---|---|---|
| **Open meeting links in** | Meeting links open here unless you send a service somewhere else below. | `defaultBrowser` · `Browser(name: "Default Browser", path: "", arguments: "", deletable: false)` |
| **Send some services somewhere else** | Pick an app and Punctual opens that service in it, ignoring the browser above. Pick a browser and it opens there instead. | `providerBrowsers` · `[:]`<br>`providerOpeningModes` · `[:]` |
| **New meetings use** |  | `createMeetingService` · `.zoom`<br>`createMeetingServiceUrl` · `""` |
| **Open new meetings in** |  | `browserForCreateMeeting` · `systemDefaultBrowser` |
| **My saved links** | Standing meeting rooms and phone numbers, shown in the dropdown's Saved links block. | — |
| **Find meeting links in unusual formats** | For invites whose link Punctual doesn't spot. The whole match must itself be a valid web address. | `customRegexes` · `[]` |
<!-- settings-table:end -->
