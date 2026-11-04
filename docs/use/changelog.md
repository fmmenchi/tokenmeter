---
title: Changelog
sidebar_label: Changelog
sidebar_position: 10
---

# Changelog

What changed in each version, newest first. The update window shows the notes of the version it offers, taken from this page, and links here for the rest.

## Unreleased {#unreleased}

- **Accounts**: a work account and a personal one, each with its own card. An account is a folder Claude Code or the Codex CLI
  reads, named by a `home` in its entry of `providers.json`; the status line is set up and `/usage` asked in each account's own
  folder, the problems name the account, and a folder nobody named is found at the top of the home and offered in the panel with
  **Add it** ([Accounts](./accounts.md)).
- **Settings has an Accounts tab** in place of Providers: add, rename or remove an account, each through a sheet, with the email
  the folder is signed in with under its name ([Settings](./settings.md)).
- **The order and the visibility of the cards moved to the panel**, behind a lock: open it and the cards get arrows, an eye each
  and one on each window, and drag onto one another; a hidden card stays in sight, dimmed, until the lock closes.
- **The welcome has eight pages**: the seventh says what an account is ([The welcome](./welcome.md)).

## 0.8.0 {#v0-8-0}

Released on 2026-11-03.

- **The welcome**: the first time the app opens a version that has it, on a fresh install and on the first update alike, a small window of seven pages says where the app lives, how to read the bars, the tick, the buttons, the stats and the suggestion, and where Settings is. It can be seen again with **Show the welcome again** in Settings, General ([The welcome](./welcome.md)).
- **The pace mark is there from the first minute of a window.** It used to wait until a tenth of the window had passed, so a weekly bar had none for its first 17 hours. Until that tenth the mark says where the window stands and that the quota lasts; the "runs out before the reset" judgment still waits ([Reading the Bars](./bars.md)).
- **The stats list no window shorter than a day, for now.** Several 5-hour windows end in one day and a row has only a date, so they read as duplicates. The verdict is drawn from the weekly windows; how to show the short ones is still to be designed ([Stats](./stats.md)).
- **The panel tells the failures of the app**: a broken `providers.json`, a snapshot the app could not write and a `/usage` that stays silent are problems the panel lists, and the main actor no longer does disk work ([Troubleshooting](./troubleshooting.md)).
- **The skins read better**: nine quota colours reach 3:1 against the bar they are drawn on, the secondary text of five palettes reaches 4.5:1, and the stats, the plan chip and the captions follow the skin. One Dark gets the icon, and the warning figure and the "runs out" phrase take the skin's middle colour.
- **Fixes**: the widget draws each entry of its timeline for that entry's own date; a Codex log line without totals no longer resets what the next one is measured against; the numbers of a log line are clamped and a reset in milliseconds is read as such; the weeks of the easter eggs follow the Gregorian calendar whatever the Mac shows; the usage history is set aside only when its file is damaged; a file that needs two migrations keeps the original as its backup.
- **The download is a clean zip**: it no longer carries AppleDouble entries, so any unarchiver keeps the signature intact.

## 0.7.0 {#v0-7-0}

Released on 2026-11-02.

- **Settings in tabs**: the window shows one section at a time, chosen from a row of tabs (General, Providers, Skin, Notifications,
  Updates), and no longer one long column ([Settings](./settings.md)).
- **The skins are a grid of tiles** in the Skin tab, each with its preview and its name.

## 0.6.0 {#v0-6-0}

Released on 2026-11-02.

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
