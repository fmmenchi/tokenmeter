---
title: Architecture
sidebar_label: Architecture
sidebar_position: 2
---

# Architecture

How the pieces fit, where each file goes and which rules keep it that way. The reasons are in the
[ADRs](../adr); this page is the map.

## The pieces

| Path                        | What it is                                                                                                                                  |
| :-------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------ |
| `Sources/TokenMeterCore`    | A Swift package target: log reading, window maths, the `Snapshot`, the problems and their fixes, the usage store and the statistics. No UI. |
| `Sources/tokenmeter-probe`  | A terminal tool that prints each provider's windows. Not a product surface.                                                                 |
| `App/TokenMeter`            | The host app: menu-bar item, panel, Settings, refresh loop, launch at login.                                                                |
| `Widget/TokenMeterWidget`   | The WidgetKit extension. It only draws a `Snapshot`.                                                                                        |
| `Tests/TokenMeterCoreTests` | XCTest; fixtures go to a temp directory, never to real logs.                                                                                |
| `project.yml`               | XcodeGen spec for the app and widget; `TokenMeter.xcodeproj` is generated.                                                                  |
| `scripts/`                  | Installer, status-line script, signing and notarization ([commands](./commands.md)).                                                        |
| `docs/`, `apps/docusaurus`  | This site: content in `docs/`, the Docusaurus app in `apps/docusaurus`.                                                                     |

## Data flow

```text
 ~/.claude/projects/*.jsonl ─┐                       ┌─> App panel (SwiftUI)
 ~/.codex/sessions/*.jsonl ──┼─> ConfiguredSource ─> Collector ─> Snapshot ─┤
 ~/.tokenmeter/*statusline ──┘   (one per entry of     (no provider named) └─> snapshot.json ─> Widget
                                   providers.json)                             (App Group container)
```

1. **Sources.** `Providers.standard()` reads `~/.tokenmeter/providers.json` and builds one
   `ConfiguredSource` per entry. If the file is missing the app writes a seed with Claude and ChatGPT
   ([ADR 0003](../adr/0003-providers-in-one-config-file.md)).
   A broken file is never overwritten: the seed runs for that launch.
2. **Reading.** A source's `read(since:)` returns a `ProviderReading`: usage events, quotas the
   provider itself reported, a plan name. It scans incrementally and keeps per-file state, so a source
   instance is long-lived ([ADR 0001](../adr/0001-app-architecture.md)).
3. **Collecting.** `Collector.snapshot(now:)` asks every source for the last seven days and hands each
   reading to `SnapshotBuilder`, which builds the windows a provider declares. It never names a
   provider ([ADR 0003](../adr/0003-providers-in-one-config-file.md)).
4. **Showing.** `Meter` (the app's `@Observable` model) runs the collector off the main actor, once at
   launch and every 60 seconds, publishes the snapshot to the panel, writes it to the App Group
   container and asks WidgetKit to reload.
5. **Keeping.** After each refresh, off the main actor, `UsageIngestor` reads the same files with sources of its own (the first
   pass reads everything the tools still keep, later ones only what is new) and puts them in `UsageStore`, a SQLite file of facts
   (messages and readings of a window) with a unique key each. `UsageStats` draws the stats view from that file with pure
   functions, never from the logs ([ADR 0010](../adr/0010-the-usage-store.md)). The widget does not read the store.

6. **Telling.** After each snapshot, if a notice is on and macOS allows it, `Meter` calls `LimitNotices.evaluate` with the snapshot it
   draws, keeps the ledger it returns in the user defaults and hands each due notice to `Notifier`, which posts it to the system
   ([ADR 0012](../adr/0012-limit-notices.md)). The rule is in the core; the widget does not read the ledger.

7. **Smiling.** In the week of an event, `Meter.rollEasterEgg` picks from the core an icon and a corner piece each time the panel
   opens, and the panel hands them to its views through the environment; `Shared/EasterEggs/` draws them and the widget never
   sets the value. Everything of the feature is in four folders: the core, `Shared/`, the images and the tests.

8. **Dressing.** The skin the person chose is kept by `Meter` in the defaults and written to the snapshot it publishes
   ([ADR 0013](../adr/0013-skins.md)). The panel and the widget put it in the environment with `skinned(_:)` and take their
   background colour from it; the shared views (the bar, the card, the tick, the plan chip) read the style from the environment and
   draw as before where there is none, which is System.

9. **Reading.** How the bars read, left or used, is kept by `Meter` in the defaults and written to the snapshot with the skin
   ([ADR 0006](../adr/0006-display-preferences.md)). The panel and the widget put it in the environment once, and `WindowRow` and
   `ScopedWindowRow` take the figure, the fill and the mark from it; the colour, the notices and the stats stay on what is left.

## The window maths

For each window a provider declares (`5h`, `7d`), the builder sums the tokens whose date falls inside
it and attaches the remaining fraction **only if** it can say where it came from
([ADR 0002](../adr/0002-quota-model-and-data-sources.md)). `WindowUsage.source` is one of:

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
`<TeamID>.tokenmeter` ([ADR 0001](../adr/0001-app-architecture.md)). The app is unsandboxed because it reads
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
