---
title: Changelog
sidebar_label: Changelog
sidebar_position: 10
---

# Changelog

What changed in each version, newest first. The update window shows the notes of the version it offers, taken from this page, and links here for the rest.

## Unreleased {#unreleased}

- **Skins**: five looks for the panel, the widget and the stats, chosen in Settings: System, Dracula, One Dark, Catppuccin and
  Nord. Each has its own colours, its own bars and its own typeface, in the dark and in the light appearance
  ([Skins](./skins.md)).
- The **licences** of the themes whose colours the skins use are on the [Licences](./licenses.md) page.

## 0.5.1 {#v0-5-1}

Released on 2026-11-02.

- **The pace tick is easier to read**: the tick that says a quota will last is now solid white in the dark appearance and black in the light one. In the dark appearance it was drawn dark grey over the bright green bar.
- **The icons of the easter eggs are bigger and clearer** on the bars and on the cards, and sharp on a Retina display. The cobweb on the bars is now a wrapped candy.
- A bar of an estimated figure fades, and its icon does not.

## 0.5.0 {#v0-5-0}

Released on 2026-11-02.

- **Seasonal easter eggs**: in the week of Halloween, Christmas and Easter, a small icon on the bars and a corner piece on
  the cards, picked at random each time you open the panel ([Seasonal easter eggs](./seasonal-easter-eggs.md)).
- **A bar with a pace tick is as thick as one without**: the Weekly bar was 40% thicker than the 5-hour bar when it had a tick.
- A page of **[Licences](./licenses.md)**.

## 0.4.0 {#v0-4-0}

Released on 2026-11-02.

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
