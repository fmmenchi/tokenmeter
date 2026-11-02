---
title: Changelog
sidebar_label: Changelog
sidebar_position: 10
---

# Changelog

What changed in each version, newest first. The update window and the panel notice open this page at the version they offer.

## 0.4.0 {#v0-4-0}

Not released yet.

- **Notifications**, off until you turn them on: _almost out_ (under 10% left), _running low_ (under 30%) and _will run out before
  the reset_, each told once for a window and its reset ([Notifications](./notifications.md)).

## 0.3.0 {#v0-3-0}

Released on 2026-11-02. It is the first version that updates itself, so it is installed by hand over v0.2.0 or v0.1.0.

- **The app updates itself.** It looks once a day, tells you, and installs when you agree; there is a switch and a **Check now** in
  Settings ([Updates](./updates.md)).
- **The menu bar is the icon**, as other apps have it. The percentage and the "▲ N" are gone; a **dot** on the icon says that the
  panel lists a problem, or that an update waits.
- **A launch reads only what changed.** The app remembers when it last read each provider and does not read every log again at
  each start, so an update or a restart no longer repeats the first minute or two of the stats.

## 0.2.0 {#v0-2-0}

- **Stats**: a second view of the panel, behind the chart icon, that says how each window ended, whether you hit the ceiling and
  which models used the tokens ([Reading the Stats](./stats.md)).
- The app asks Claude Code to run `/usage` every 15 minutes, so Claude's quota is the account's.
- Signed with a Developer ID certificate and notarized.

## 0.1.0 {#v0-1-0}

- The first release: the menu-bar panel, the widget and the Settings, for Claude and ChatGPT.
