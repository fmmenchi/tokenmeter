# ADR 0003 — Host app, widget extension and App Group

Status: accepted (2026-10-28)

## Context

ADR 0001 split collection (host app) from rendering (widget). The widget extension is
sandboxed and cannot read `~/.claude` or `~/.codex`; the host app can, if it is not sandboxed.

## Decision

- The **host app** is a menu-bar-only app (`LSUIElement`), **not sandboxed**, so it can read the
  two log trees. It refreshes every 60 seconds, writes `snapshot.json` into the App Group
  container `group.com.fmmenchi.tokenmeter.app` and asks WidgetKit to reload.
- The **widget extension** is sandboxed, reads only that file, and renders it.
- ~~Token limits for `estimated` windows are user settings~~ — removed by ADR 0009.
- The Xcode project is generated from `project.yml` by XcodeGen; the `.xcodeproj` is not committed.
- The signing team is not committed: `Local.xcconfig` (git-ignored, template in
  `Local.xcconfig.example`) sets `DEVELOPMENT_TEAM`.

## Consequences

- A non-sandboxed app cannot ship on the Mac App Store. This is a personal tool: accepted.
- An App Group needs a signing team. Without one the project compiles but the widget cannot read
  the snapshot, so CI only builds with signing disabled.
