# ADR 0011 — Launch at login

Status: accepted (2026-10-28)

## Context

The widget is only fed while the host app runs (ADR 0003). If the app is not running after a
restart, the widget shows stale data. Adding a Login Item by hand is a step people forget.

## Decision

The app registers itself as a login item with `SMAppService.mainApp` the first time it runs, and
records that it did. The panel has a **Launch at login** switch. If the user turns it off, the app
never turns it back on: the first-run registration happens once.

## Consequences

- macOS lists the app under System Settings, General, Login Items and may show a notice the first
  time.
- Registration is tied to the app's location. Moving the app, or running a copy from a build
  folder, registers that copy; the one in `/Applications` is the one meant to start at login.
- An unsigned or differently signed copy may fail to register; the failure is ignored and the
  switch shows the real status.
