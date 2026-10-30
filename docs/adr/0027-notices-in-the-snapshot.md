# ADR 0027 — Notices in the snapshot, and a light background check

Status: accepted (2026-10-30); amends [ADR 0026](./0026-warn-when-a-project-overrides-the-status-line.md)

## Context

[ADR 0026](./0026-warn-when-a-project-overrides-the-status-line.md) put its warning in Settings, a
window almost nobody opens. The place where frozen Claude bars are noticed is the widget and the
panel. The widget reads only `snapshot.json`, so a warning it can show has to travel in the snapshot.
The check must not get in the way: no dialog, nothing that blocks, and little work.

## Decision

- `Snapshot` gets `notices: [String]`, plain sentences, empty by default and absent from older files
  (decoded as empty). Only the app writes them; the collector does not.
- The widget and the panel show them as one small orange line each, below the bars. Settings keeps its
  warning. Nothing is modal and nothing waits on the user.
- The projects check runs **in the background at utility priority**: at launch, and after that at most
  once every 10 minutes, piggybacking on the existing 60-second refresh. It reads at most 200 small
  files; between runs the last result is reused. The text comes from one function in the core
  (`ProjectStatusLines.notice(for:)`), so the three places say the same thing.

## Consequences

- A frozen Claude bar next to a project override explains itself on the desktop.
- The snapshot format grew by one optional key; a widget older than the app ignores it.
- A project fixed by the user keeps its notice for up to 10 minutes.
