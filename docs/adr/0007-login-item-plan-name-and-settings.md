# ADR 0007 — The login item, the plan name and the Settings window

Status: accepted (2026-10-28, consolidated 2026-11-02 from the ADRs on launch at login, the plan name and the Settings window)

## Context

The widget is fed only while the host app runs ([ADR 0001](./0001-app-architecture.md)); the bars do not say which plan they are
about; and a preference does not belong in a panel meant for reading the bars.

## Decision

- **Launch at login:** the app registers itself with `SMAppService.mainApp` the first time it runs and records that it did. If the
  user turns it off the app never turns it back on. Registration is tied to the app's location, so the copy in `/Applications` is
  the one meant to start at login; a failure to register is ignored and the switch shows the real status.
- **The plan name:** ChatGPT's comes from `plan_type` in the `rate_limits` of the Codex logs; Claude's from `organizationType` and
  `organizationRateLimitTier` under `oauthAccount` in `~/.claude.json`. The readers decode **only those fields**: the profile also
  holds an email, a name and identifiers, and none of them are read into the snapshot. A label is made from the raw values and
  omitted when there is none ([ADR 0003](./0003-providers-in-one-config-file.md)'s `plan.labels`).
- **Settings is a `Window` scene, not the `Settings` scene**: `SettingsLink` does not open from a menu-bar-only app. The panel's
  **Settings…** button activates the app and switches it to a regular one while the window is open, because an accessory app is never
  frontmost, and `SettingsView` puts it back to accessory when it disappears.

## Consequences

- macOS lists the app under Login Items and may show a notice the first time; a differently signed copy may fail to register.
- `~/.claude.json` is not a documented interface: if its fields move, the label disappears and nothing else breaks.
- One window holds every preference, and new ones have a place to go.
