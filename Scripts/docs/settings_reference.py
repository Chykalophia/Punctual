#!/usr/bin/env python3
"""Generates the per-pane settings tables in docs/user-guide/preferences/*.md.

Reads three sources of truth so the tables never drift from the app:
  * Punctual/Preferences/SettingsIndex.swift   - every user-facing setting, by pane
  * Punctual/Resources /Localization /en.lproj - the English label and help text
  * Punctual/Extensions/DefaultsKeys.swift      - the stored key and its default

Each pane page carries a block between these markers, which this script rewrites:
  <!-- settings-table:begin -->
  <!-- settings-table:end -->

Usage: python3 Scripts/docs/settings_reference.py [--check]
--check exits 1 when a page is out of date (for CI).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "Punctual/Preferences/SettingsIndex.swift"
STRINGS = ROOT / "Punctual/Resources /Localization /en.lproj/Localizable.strings"
DEFAULTS = ROOT / "Punctual/Extensions/DefaultsKeys.swift"
OUT = ROOT / "docs/user-guide/preferences"

PANE_FILES = {
    "calendars": "calendars.md",
    "filters": "filters.md",
    "menuBar": "menu-bar.md",
    "dropdown": "dropdown.md",
    "calendarWindow": "grid.md",
    "joining": "joining.md",
    "alerts": "alerts.md",
    "general": "general.md",
}
BEGIN, END = "<!-- settings-table:begin -->", "<!-- settings-table:end -->"


def load_strings():
    text = STRINGS.read_text(encoding="utf-8")
    pairs = re.findall(r'^"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)";', text, re.M)
    return {k: v.replace('\\"', '"').replace("\\n", " ") for k, v in pairs}


def load_entries():
    text = INDEX.read_text(encoding="utf-8")
    entries = []
    for block in re.findall(r"SettingsIndexEntry\((.*?)\n\s*\)", text, re.S):
        if "id:" not in block:
            continue
        def field(name):
            m = re.search(name + r':\s*"([^"]+)"', block)
            return m.group(1) if m else None
        tab = re.search(r"tab:\s*\.(\w+)", block)
        keys = re.search(r"defaultsKeys:\s*\[(.*?)\]", block, re.S)
        entries.append({
            "id": field("id"),
            "tab": tab.group(1) if tab else None,
            "label": field("labelKey"),
            "help": field("helpKey"),
            "keys": re.findall(r'"([^"]+)"', keys.group(1)) if keys else [],
        })
    return entries


def load_defaults():
    text = DEFAULTS.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'Key<(.+?)>\(\s*"(\w+)"\s*,\s*default:\s*(.+?)\)\s*$', text, re.S | re.M):
        value = " ".join(m.group(3).split())
        out[m.group(2)] = value
    return out


def cell(text):
    return (text or "").replace("|", "\\|").strip()


def render(tab, entries, strings, defaults):
    rows = ["| Setting | What it does | Stored as · default |", "|---|---|---|"]
    for e in entries:
        if e["tab"] != tab:
            continue
        label = strings.get(e["label"], e["label"])
        help_text = strings.get(e["help"], "") if e["help"] else ""
        stored = "<br>".join(
            f"`{k}` · `{defaults[k]}`" if k in defaults else f"`{k}`" for k in e["keys"]
        ) or "—"
        rows.append(f"| **{cell(label)}** | {cell(help_text)} | {stored} |")
    return "\n".join(rows)


def main():
    check = "--check" in sys.argv
    strings, entries, defaults = load_strings(), load_entries(), load_defaults()
    stale = []
    for tab, name in PANE_FILES.items():
        page = OUT / name
        text = page.read_text(encoding="utf-8")
        if BEGIN not in text:
            sys.exit(f"{page}: missing {BEGIN}")
        head, rest = text.split(BEGIN, 1)
        if END not in rest:
            sys.exit(f"{page}: missing {END}")
        _, tail = rest.split(END, 1)
        note = ("_Generated from `SettingsIndex.swift` by `Scripts/docs/settings_reference.py`. "
                "Do not edit by hand._\n\n")
        new = f"{head}{BEGIN}\n{note}{render(tab, entries, strings, defaults)}\n{END}{tail}"
        if new != text:
            stale.append(page)
            if not check:
                page.write_text(new, encoding="utf-8")
    if check and stale:
        sys.exit("Out of date: " + ", ".join(str(p.relative_to(ROOT)) for p in stale))
    print(f"{len(entries)} settings across {len(PANE_FILES)} panes" + (" (checked)" if check else ""))


if __name__ == "__main__":
    main()
