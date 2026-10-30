---
title: Core API
sidebar_label: Core API
sidebar_position: 3
---

# Core API

The public surface of `TokenMeterCore`, the Swift package that the app, the widget and the probe
share. Add it with `import TokenMeterCore`. Everything is `Sendable`; nothing in it draws UI.

## Provider contract

```swift
public protocol ProviderSource: Sendable {
    var info: ProviderInfo { get }
    func read(since: Date) -> ProviderReading
}
```

| Type              | Fields                                                                       |
| :---------------- | :--------------------------------------------------------------------------- |
| `Provider`        | A string-backed id: `.claude`, `.chatgpt`, or `Provider(rawValue:)`.         |
| `ProviderInfo`    | `provider`, `title`, `windows: [WindowSpec]`, `setupHint`.                   |
| `ProviderReading` | `events: [UsageEvent]`, `quotas: [ReportedQuota]`, `plan`, `quotaUpdatedAt`. |
| `UsageEvent`      | `provider`, `date`, `tokens: TokenCounts`.                                   |
| `ReportedQuota`   | `usedPercent`, `windowMinutes`, `resetsAt`, `observedAt`.                    |
| `TokenCounts`     | `input`, `output`, `cacheRead`, `cacheWrite`, `total`, and `+`.              |
| `WindowSpec`      | `name`, `duration`; `.session` (`5h`) and `.week` (`7d`).                    |

`read(since:)` must not throw and must tolerate bad lines: return what it could read.

## Building sources

| Symbol                                         | Does                                                                               |
| :--------------------------------------------- | :--------------------------------------------------------------------------------- |
| `Providers.standard(config:home:)`             | The list of sources from `providers.json`; seeds it when missing.                  |
| `ConfiguredSource(_:home:)`                    | A source driven by one `ProviderConfig` ([format](../use/configure-providers.md)). |
| `ProviderConfigFile.load(from:)`               | Decodes the file; throws `Failure` (printable) when it is broken.                  |
| `ProviderConfigFile.seed()`, `.writeSeed(to:)` | The built-in Claude and ChatGPT entries.                                           |
| `PlanName.prettified(_:)`                      | `team_plus` to `Team Plus`.                                                        |

Pass a throwaway `home:` in tests so nothing reads the real `~`.

## Collecting

```swift
let snapshot = Collector().snapshot()                       // every provider in providers.json
let one = Collector(sources: [mySource]).snapshot(now: date) // your own list, fixed clock
```

`Collector` asks every source for seven days and builds each provider's windows through
`SnapshotBuilder.providerSnapshot(...)`.

## The snapshot

| Type                 | Fields                                                                                |
| :------------------- | :------------------------------------------------------------------------------------ |
| `Snapshot`           | `generatedAt`, `providers: [ProviderSnapshot]`, `problems: [Problem]`.                |
| `ProviderSnapshot`   | `provider`, `title`, `windows: [WindowUsage]`, `plan`, `quotaUpdatedAt`, `setupHint`. |
| `WindowUsage`        | `window`, `tokens`, `remainingFraction?`, `source`, `resetsAt?`, `observedAt?`.       |
| `WindowUsage.Source` | `reported`, `reset`, `consumptionOnly`.                                               |

`WindowUsage.resolved(at:)` returns the window as it reads at a given time. The JSON shape is in
[Commands and Files](./commands.md#the-snapshot); older snapshots without `title` or `problems` still decode.

## Problems

What the app tells the person is a `Problem`, not a string
([ADR 0030](../adr/0030-problems-with-a-topic-and-a-fix.md),
[ADR 0031](../adr/0031-problems-come-from-the-app-and-from-provider-integrations.md)). Everything is in
`Sources/TokenMeterCore/Problems/`.

| Type                  | What it is                                                                                                          |
| :-------------------- | :------------------------------------------------------------------------------------------------------------------ |
| `Problem`             | `id`, `topic` (a provider id or `general`), `message`, `detail?`, `explanation?`, `fix?`, `guide?`.                 |
| `ProblemKind`         | One kind of problem: id, topic, summary, explanation, guide and fix. `problem(...)` makes a `Problem` of that kind. |
| `ProviderIntegration` | One per provider that needs one: its `kinds`, its `fixes`, `problems(in:)` and `run(fix:in:)`.                      |
| `Integrations`        | The registry by id; `census` lists every kind of the app and of each integration.                                   |
| `ProblemDetector`     | `detect(...)` gathers the problems of the app and of each configured integration; `merge(...)` orders and dedupes.  |
| `FixRunner`           | Runs a problem's fix through the integration that declared it; answers `FixResult.done` or `.failed(reason)`.       |
| `Dismissals`          | What was hidden, by id and message, until the message changes. `DefaultsDismissals` keeps it in the app's defaults. |

`providers.json` names a provider's integration in an optional `integration` field; the registry maps it to code, and
an unknown id is a `general` problem, not a crash. An existing file whose `claude` entry lacks the field gets it once,
with a backup ([ADR 0033](../adr/0033-add-the-claude-integration-to-an-existing-providers-file.md)).

## Display preferences

The order of the cards and the windows each shows are preferences of the app, not of `providers.json`
([ADR 0035](../adr/0035-provider-cards-order-and-windows-are-preferences.md), [ADR 0036](../adr/0036-a-provider-can-be-hidden.md)).

| Type                         | What it is                                                                                      |
| :--------------------------- | :---------------------------------------------------------------------------------------------- |
| `DisplayPreferences`         | `order`, `windows(for:)` (nil means every window), `setOrder`, `setWindows`, and `ordered(_:)`. |
| `DefaultsDisplayPreferences` | Keeps them in the app's defaults, by provider id.                                               |
| `Snapshot.applying(_:)`      | Orders the providers and drops the hidden windows; a choice that matches none shows them all.   |

The app applies them when it writes the snapshot, so the widget draws what it is given.

## Sharing with the widget

| Symbol                            | Does                                                                            |
| :-------------------------------- | :------------------------------------------------------------------------------ |
| `SnapshotStore.appGroup`          | The App Group id from the Info.plist, `<TeamID>.tokenmeter`; `nil` without one. |
| `SnapshotStore.appGroupStore()`   | The store in the App Group container, or `nil` without a team.                  |
| `store.write(_:)`, `store.read()` | Write and read `snapshot.json`.                                                 |

## Extending

- **A new tool with a plain JSONL log**: add an entry to `providers.json`, no Swift
  ([Configure Providers](../use/configure-providers.md)).
- **A log the format cannot describe**: implement `ProviderSource`
  ([Add a Provider](./add-a-provider.md)).
- **A problem or a fix for a provider**: implement `ProviderIntegration`
  ([Add a Provider](./add-a-provider.md#step-4-optional-report-its-problems)).

## Related

- [Architecture](./architecture.md)
- [Data Sources](./data-sources.md)
