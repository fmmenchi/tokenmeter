---
title: Updates
sidebar_label: Updates
sidebar_position: 9
---

# Updates

tokenmeter looks for a new version once a day, tells you when there is one, and installs it when you agree. The widget is part
of the app, so it updates with it.

## What it does

- **Once a day** it asks GitHub for a short file that lists the versions
  (`https://github.com/fmmenchi/tokenmeter/releases/latest/download/appcast.xml`). It sends nothing about you, your plans or your
  use, and no system profile.
- When there is a newer version the system's update window asks you. **Nothing is installed without a yes.**
- If you did not see the window, the panel shows a **notice at its top**, "Version N is available" with **What's new** and
  **Install**, and the menu-bar icon carries a **dot** (the same dot that a problem puts there).
- **Install** quits the app, replaces it, opens it again, and the app migrates what it keeps. Your settings and your history stay,
  and the stats are not read again from nothing.
- **What's new** opens the [changelog](./changelog.md) at that version.

## Settings

At the foot of Settings, a group **Updates** shows the installed version and has:

- a switch **Update automatically**, on by default. Off, the app never contacts GitHub on its own;
- a line that says when it last looked, and a button **Check now**. If a check fails (offline, for instance) the line says so,
  and the button says **Try again**.

## Good to know

- **The first version with updates is installed by hand**, by dragging it to `/Applications` over the old one. Versions before it
  (v0.1.0 and v0.2.0) do not look for updates. From then on the app updates itself.
- An update is signed with a key that only the author has, and the app refuses one that does not match.
- A build you made yourself has no key, so it does not look for updates: Settings says so.
- The widget on the desktop can take a moment to show the new version after an update.
- Nothing about this leaves your Mac except that one request for the list.

## Related

- [Install tokenmeter](./install.md)
- [Changelog](./changelog.md)
