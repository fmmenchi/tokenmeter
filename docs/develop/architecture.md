---
title: Architecture
sidebar_label: Architecture
sidebar_position: 2
---

# Architecture

How the pieces fit, where each file goes and which rules keep it that way. The reasons are in the
[ADRs](../adr); this page is the map.

## The pieces

| Path                        | What it is                                                                           |
| :-------------------------- | :----------------------------------------------------------------------------------- |
| `Sources/TokenMeterCore`    | A Swift package target: log reading, window maths, the `Snapshot`. No UI.            |
| `Sources/tokenmeter-probe`  | A terminal tool that prints each provider's windows. Not a product surface.          |
| `App/TokenMeter`            | The host app: menu-bar item, panel, Settings, refresh loop, launch at login.         |
| `Widget/TokenMeterWidget`   | The WidgetKit extension. It only draws a `Snapshot`.                                 |
| `Tests/TokenMeterCoreTests` | XCTest; fixtures go to a temp directory, never to real logs.                         |
| `project.yml`               | XcodeGen spec for the app and widget; `TokenMeter.xcodeproj` is generated.           |
| `scripts/`                  | Installer, status-line script, signing and notarization ([commands](./commands.md)). |
| `docs/`, `apps/docusaurus`  | This site: content in `docs/`, the Docusaurus app in `apps/docusaurus`.              |

## Data flow

```text
 ~/.claude/projects/*.jsonl ─┐                       ┌─> App panel (SwiftUI)
 ~/.codex/sessions/*.jsonl ──┼─> ConfiguredSource ─> Collector ─> Snapshot ─┤
 ~/.tokenmeter/*statusline ──┘   (one per entry of     (no provider named) └─> snapshot.json ─> Widget
                                   providers.json)                             (App Group container)
```

1. **Sources.** `Providers.standard()` reads `~/.tokenmeter/providers.json` and builds one
   `ConfiguredSource` per entry. If the file is missing the app writes a seed with Claude and ChatGPT
   ([ADR 0016](../adr/0016-providers-declared-in-a-config-file.md), [0018](../adr/0018-the-config-file-is-the-only-source.md)).
   A broken file is never overwritten: the seed runs for that launch.
2. **Reading.** A source's `read(since:)` returns a `ProviderReading`: usage events, quotas the
   provider itself reported, a plan name. It scans incrementally and keeps per-file state, so a source
   instance is long-lived ([ADR 0004](../adr/0004-incremental-log-scanning.md)).
3. **Collecting.** `Collector.snapshot(now:)` asks every source for the last seven days and hands each
   reading to `SnapshotBuilder`, which builds the windows a provider declares. It never names a
   provider ([ADR 0015](../adr/0015-provider-contract.md)).
4. **Showing.** `Meter` (the app's `@Observable` model) runs the collector off the main actor, once at
   launch and every 60 seconds, publishes the snapshot to the panel, writes it to the App Group
   container and asks WidgetKit to reload.

## The window maths

For each window a provider declares (`5h`, `7d`), the builder sums the tokens whose date falls inside
it and attaches the remaining fraction **only if** it can say where it came from
([ADR 0007](../adr/0007-expired-window-reads-as-reset.md)). `WindowUsage.source` is one of:

| `source`          | Meaning                                                                     |
| :---------------- | :-------------------------------------------------------------------------- |
| `reported`        | The provider wrote the percentage in its own log or status line.            |
| `reset`           | A reported window expired and nothing was used since: full again, inferred. |
| `consumptionOnly` | Tokens only; no remaining figure can be stated.                             |

`WindowUsage.resolved(at:)` turns a `reported` figure whose `resetsAt` has passed into `reset`, at
any age of the snapshot, so a stale file never shows a stale percentage as current.

## Host app, widget and the App Group

The widget cannot read your logs, so the host app does the collecting and the widget renders what it
finds in `snapshot.json`, inside the App Group container
`group.com.fmmenchi.tokenmeter.app` ([ADR 0003](../adr/0003-host-app-widget-and-app-group.md),
[0020](../adr/0020-bundle-identifiers-under-the-paid-team.md)). The app is unsandboxed because it reads
other tools' files; the widget is sandboxed. An App Group needs a signing team, which is why a build
needs `DEVELOPMENT_TEAM` in `Local.xcconfig`.

## Rules

- The widget renders a `Snapshot`; collection lives in the host app.
- Every provider is a `ProviderSource` from `Providers.standard()`. Write Swift only for a log the
  config format cannot describe ([Add a Provider](./add-a-provider.md)).
- Window maths, bars and refresh are common and never name a provider.
- A remaining-quota figure carries its `source`. Never show a percentage the code cannot attribute to a
  provider log or a reset window.
- Provider log formats are not contracts: decode tolerantly (optional fields, skip bad lines) and add
  a test with the exact shape that broke.
- A structural decision gets an ADR before the code.

## Related

- [Core API](./core-api.md)
- [Concepts](./concepts.md)
- [Data Sources](./data-sources.md)
