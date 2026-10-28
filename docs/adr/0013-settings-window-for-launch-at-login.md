# ADR 0013 — A Settings window for launch at login

Status: accepted (2026-10-28)

## Context

ADR 0011 put the **Launch at login** switch in the menu-bar panel. A preference does not belong in
a panel meant for reading the bars. ADR 0009 removed the old Limits window, so the app has no
settings surface.

## Decision

The panel has a **Settings…** button that opens a small window with the **Launch at login** switch.
The window is a `Window` scene, not the `Settings` scene: `SettingsLink` does not open from a
menu-bar-only app, which is what made the old Limits button fail. The button activates the app
first, because an accessory app is never frontmost. Activating was not enough on its own: the button
also switches the app to a regular one while the window is open, and `SettingsView` returns it to
accessory when it disappears.

## Consequences

- One more window to maintain, for one setting; new preferences have a place to go.
- ADR 0011's behaviour is unchanged (register once on first run, never re-enable after the user
  turns it off); only where the switch lives moves.
