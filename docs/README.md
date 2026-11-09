# Punctual docs

This folder holds two kinds of documentation.

## For people using Punctual

**[User guide](user-guide/README.md)**: every window, menu, notification, email touchpoint and setting, with screenshots generated from the app. It's written so each page can become a page on a docs site as-is: relative links, one topic per file, and images beside the pages that use them.

## For people working on Punctual

| File | What it is |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | How the app is put together. Read before changing app flow. |
| [RELEASING.md](RELEASING.md) | Signing, notarizing and publishing a release |
| [FEATURES.md](FEATURES.md) | Testing notes for the Dot-parity features |
| [DROPDOWN-MODERNIZATION.md](DROPDOWN-MODERNIZATION.md), [DROPDOWN-POLISH.md](DROPDOWN-POLISH.md), [PREFERENCES-UX-PLAN.md](PREFERENCES-UX-PLAN.md) | Design plans of record |
| [brand/](brand/) | Icon sources |
| [screenshots/](screenshots/) | README and website images (`make screenshots`) |

## Why the docs live in this repo

The user guide sits next to the code because most of it is generated from the code: the settings tables come from `SettingsIndex.swift`, and every screenshot is rendered from the app's own views. Keeping both in one repo means a UI change and its docs land in the same pull request, and CI fails when a setting is added without the guide picking it up (`make docs-settings-check`).

To publish it as a site (for example at chykalophia.com/punctual/docs), point a static-site generator such as MkDocs or VitePress at `docs/user-guide`. Move to a separate docs repo only if the guide grows content that isn't tied to the app's code, such as tutorials or marketing pages.
