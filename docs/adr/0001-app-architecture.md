# ADR 0001 — App architecture: a host app, a widget that renders, a snapshot in between

Status: accepted (2026-10-28, consolidated 2026-11-02 from the first ADRs on stack, host and widget, scanning, polling and the App Group)

## Context

tokenmeter is a macOS widget, and desktop and Notification Center widgets are WidgetKit-only. A widget cannot run
long-lived work and is sandboxed, so it cannot read the logs of the CLIs it reports on.

## Decision

- **A native SwiftUI app with three parts:** a host app with a `MenuBarExtra` that owns data collection, a WidgetKit extension
  that only renders, and a shared Swift package (`TokenMeterCore`) for models and parsing. The XcodeGen project is generated
  from `project.yml`; the `.xcodeproj` is not committed, and the signing team is not either (`Local.xcconfig`, git-ignored).
- **The host app is menu-bar only (`LSUIElement`) and not sandboxed**, so it can read `~/.claude` and `~/.codex`. It refreshes
  every 60 seconds and on every open of the panel, writes `snapshot.json` into the App Group container and asks WidgetKit
  to reload. The widget reads only that file and computes nothing.
- **The App Group is `<TeamID>.tokenmeter`**, written into the entitlement as `$(TeamIdentifierPrefix)tokenmeter` and into each
  Info.plist as `AppGroupIdentifier`. A group named `group.…` needs registering in the developer account, which was never
  done; the team-prefixed one needs nothing. `SnapshotStore.appGroup` reads the key and is `nil` where there is none (probe,
  tests). A failed write is logged, and the widget is reloaded only after a successful one.
- **Log scanning is incremental.** Each reader keeps, per file, the byte offset it parsed up to and the events found; a refresh
  reads only the bytes appended since, up to the last complete line, and a file that shrank is re-read. Events older than
  seven days are pruned. A full scan of 7.5 GB took 31 s, more than the refresh interval.
- **No polling of provider endpoints.** Neither the OAuth usage endpoint with the token Claude Code keeps in the Keychain
  (a background app would hold a credential and call an undocumented API), nor `claude -p` on a timer (it spends the quota it
  measures). A stale figure is labelled, not refreshed ([ADR 0002](./0002-quota-model-and-data-sources.md)). A live endpoint
  needs its own ADR on the Keychain.

## Consequences

- It needs Xcode and a signing team for the App Group; without one the project compiles and the widget cannot read the
  snapshot, so CI builds with signing disabled.
- A non-sandboxed app cannot ship on the Mac App Store ([ADR 0008](./0008-signing-and-distribution.md)).
- Widget refresh is budgeted by the system; the menu-bar panel is the live view.
- The first scan after launch costs seconds and runs off the main thread. A log rewritten in place at the same size would be
  missed; both CLIs only append.
- Claude's bars can lag as long as no session runs.
- Verified on the author's Mac with the Developer ID build of v0.2.0: the sandboxed widget reads the snapshot on the desktop. Not verified: the double click of a notarized build on another Mac.
