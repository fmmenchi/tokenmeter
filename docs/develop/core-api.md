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

| Type              | Fields                                                                                                   |
| :---------------- | :------------------------------------------------------------------------------------------------------- |
| `Provider`        | A string-backed id: `.claude`, `.chatgpt`, or `Provider(rawValue:)`.                                     |
| `ProviderInfo`    | `provider`, `title`, `windows: [WindowSpec]`, `setupHint`.                                               |
| `ProviderReading` | `events: [UsageEvent]`, `quotas: [ReportedQuota]`, `history: [WindowReading]`, `plan`, `quotaUpdatedAt`. |
| `UsageEvent`      | `provider`, `date`, `tokens: TokenCounts`, `model`, `key` (both optional).                               |
| `WindowReading`   | `windowMinutes`, `resetsAt`, `usedPercent`, `firstObserved`, `lastObserved`: a window a log reported.    |
| `ReportedQuota`   | `usedPercent`, `windowMinutes`, `resetsAt`, `observedAt`.                                                |
| `TokenCounts`     | `input`, `output`, `cacheRead`, `cacheWrite`, `total`, and `+`.                                          |
| `WindowSpec`      | `name`, `duration`; `.session` (`5h`) and `.week` (`7d`).                                                |

`read(since:)` must not throw and must tolerate bad lines: return what it could read.

## Building sources

| Symbol                                                                        | Does                                                                                                                                            |
| :---------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| `Providers.standard(config:home:)`                                            | The list of sources from `providers.json`; seeds it when missing.                                                                               |
| `ConfiguredSource(_:home:)`                                                   | A source driven by one `ProviderConfig` ([format](../use/configure-providers.md)).                                                              |
| `ProviderConfigFile.load(from:)`                                              | Decodes the file; throws `Failure` (printable) when it is broken.                                                                               |
| `ProviderConfigFile.seed()`, `.writeSeed(to:)`                                | The built-in Claude and ChatGPT entries.                                                                                                        |
| `ProviderConfigFile.entry(for:id:title:home:)`                                | The seed entry of a tool as an account's entry, its paths moved to the folder ([ADR 0014](../adr/0014-accounts-and-the-home-of-a-provider.md)). |
| `ProviderConfigFile.add`, `.replace`, `.remove`, `.edited`, `.id(for:taken:)` | The app writes whole entries, with a `.bak`; `edited` moves only the paths the template gave; an id from a title.                               |
| `AccountTool`                                                                 | Claude Code or the Codex CLI: its seed entry, its default folder, its name.                                                                     |
| `ProviderConfig.home`                                                         | Optional: the folder the tool reads for the entry; the integration's, not the readers'.                                                         |
| `PlanName.prettified(_:)`                                                     | `team_plus` to `Team Plus`.                                                                                                                     |

Pass a throwaway `home:` in tests so nothing reads the real `~`.

## The usage store and the statistics

```swift
let store = try UsageStore(url: url)                    // makes the file and its folder; an unreadable file is made again empty
let ingestor = UsageIngestor(store: store)              // its own sources: the first pass reads every file, then what is new
ingestor.ingest()                                       // safe from any queue; a second read adds nothing
let stats = UsageStats.stats(for: .claude, windows: [300, 10080], families: rules, store: store, range: .quarter)
```

| Symbol                                                    | Does                                                                                                                   |
| :-------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------- |
| `UsageStore(url:)`                                        | The SQLite file of facts ([ADR 0010](../adr/0010-the-usage-store.md)); throws only when a newer version wrote it.      |
| `insert(_:)`, `upsert(_:)`                                | Messages are ignored when their key is there; a reading keeps the highest percentage and the first and last time seen. |
| `modelTotals`, `readings`, `oldest`                       | What the statistics read.                                                                                              |
| `UsageIngestor(sources:store:overlap:)`                   | Puts what the sources see into the store; `ingest(now:)` returns how many messages and readings were seen.             |
| `UsageStats.stats(for:windows:families:store:range:now:)` | A provider's card: the windows that closed, whether the ceiling was hit, and the models by family.                     |
| `UsageStats.outcomes`, `breakdown`, `family`              | The same pieces, pure, for tests and other views.                                                                      |
| `StatsRange`                                              | `.month`, `.quarter`, `.year`, `.lifetime`, and where each starts.                                                     |

The statistics are pure functions of the facts: the same facts give the same figures. A window with no reading is absent, never
estimated.

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

`WindowUsage.resolved(at:)` returns the window as it reads at a given time. `pace(at:)` returns its `Pace`:
`aheadFraction`, the share of the window still ahead, which is where the mark on the bar goes (when the figure was observed
for a fresh one, now for one that is out of date), `runsOutAt`, when the quota runs out at the pace since the window began
if that is before the reset (nil for a stale figure), `isStale` and `runsOut`. It is nil when nothing can be estimated.
`runsOut(at:)` is its `runsOutAt`, `paceFigureText(at:)` is what the figure on the bar's label line says while the pointer is on the bar, and `runsOutShortText(at:)` is
the phrase for the widget ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)). The JSON shape is in
[Commands and Files](./commands.md#the-snapshot); older snapshots without `title` or `problems` still decode.

## Problems

What the app tells the person is a `Problem`, not a string
([ADR 0005](../adr/0005-problems.md)). Everything is in
`Sources/TokenMeterCore/Problems/`.

| Type                  | What it is                                                                                                                                                                                        |
| :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Problem`             | `id`, `topic` (a provider id or `general`), `message`, `detail?`, `explanation?`, `fix?`, `guide?`.                                                                                               |
| `ProblemKind`         | One kind of problem: id, topic, summary, explanation, guide and fix. `problem(...)` makes a `Problem` of that kind.                                                                               |
| `ProviderIntegration` | One per tool: its `tool`, its `kinds`, its `fixes`, `problems(for:in:)` and `run(fix:for:in:)`, asked about one entry at a time ([ADR 0014](../adr/0014-accounts-and-the-home-of-a-provider.md)). |
| `AccountFolders`      | A tool's folders: the default, whether a folder is the tool's, who is signed in there, and the scan of the top of the home.                                                                       |
| `Integrations`        | The registry by id; `census` lists every kind of the app and of each integration.                                                                                                                 |
| `ProblemDetector`     | `detect(...)` gathers the problems of the app and of each configured integration, and the folders nobody named; `merge(...)` orders and dedupes.                                                  |
| `FixRunner`           | Runs a problem's fix through the integration that declared it; answers `FixResult.done` or `.failed(reason)`.                                                                                     |
| `Dismissals`          | What was hidden, by id and message, until the message changes. `DefaultsDismissals` keeps it in the app's defaults.                                                                               |

`providers.json` names a provider's integration in an optional `integration` field; the registry maps it to code, and
an unknown id is a `general` problem, not a crash. An existing file whose `claude` entry lacks the field gets it once,
with a backup, and the `chatgpt` entry gets `codex` the same way ([ADR 0003](../adr/0003-providers-in-one-config-file.md),
[ADR 0014](../adr/0014-accounts-and-the-home-of-a-provider.md)). A problem of an account has the entry's id as its topic and as the
first segment of its id: `claude-work.statusline.other`.

## Display preferences

The order of the cards and the windows each shows are preferences of the app, not of `providers.json`
([ADR 0006](../adr/0006-display-preferences.md)).

| Type                         | What it is                                                                                      |
| :--------------------------- | :---------------------------------------------------------------------------------------------- |
| `DisplayPreferences`         | `order`, `windows(for:)` (nil means every window), `setOrder`, `setWindows`, and `ordered(_:)`. |
| `DefaultsDisplayPreferences` | Keeps them in the app's defaults, by provider id.                                               |
| `Snapshot.applying(_:)`      | Orders the providers and drops the hidden windows; a choice that matches none shows them all.   |

The app applies them when it writes the snapshot, so the widget draws what it is given.

## Limit notices

When a window is running out ([ADR 0012](../adr/0012-limit-notices.md)). The rule is a pure function of the core, with no framework and
no clock of its own; the app keeps what was told and shows the notification.

| Type                    | What it is                                                                                                                             |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------------------------- |
| `NoticeKind`            | `almostOut`, `willRunOut`, `runningLow`, in the order of their urgency.                                                                |
| `LimitNotices.evaluate` | The snapshot, the kinds that are on, a `NoticeLedger` and `now` in; the `LimitNotice`s that are due and the ledger to keep out.        |
| `NoticeLedger`          | What was told, by identifier, each with the reset moment of its window; `prune(now:)` drops an entry a day after its reset. `Codable`. |
| `LimitNotice`           | The identifier (provider, window id, reset moment, kind), the kind, the provider's title and the window as it reads at `now`.          |

It counts only a reported figure that is recent (`WindowUsage.staleAfter`) with a reset still ahead, posts only the most urgent
kind that is due for a window and writes the others due as told, and never writes a kind that is off.

## Seasonal easter eggs

The week of an event and what the panel carries in it, in the folder `Sources/TokenMeterCore/EasterEggs/` and its one test file
([proposal](../features/2026-11-02-seasonal-easter-eggs/proposal.md)).

| Type             | What it is                                                                                                                                                          |
| :--------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Occasion`       | `halloween`, `christmas`, `easter`. `active(on:calendar:)` says which one's week it is, in the person's own calendar; Easter is worked out (`easterSunday(year:)`). |
| `Occasion.marks` | The names of the six icons for the bars of an event, and `corners` the six pieces for the cards, as the app's images are named.                                     |
| `EasterEgg`      | One mark and one corner of an event. `pick(for:seed:)` is the same for the same seed; `random(for:)` is what the panel calls.                                       |

The views that draw them are in `Shared/EasterEggs/` and the 36 images in `App/TokenMeter/EasterEggs/Pieces/`.

## Skins

The looks of the panel, the widget and the stats, in the folder `Sources/TokenMeterCore/Skins/` and in `SkinsTests.swift`
([ADR 0013](../adr/0013-skins.md), [proposal](../features/2026-11-02-skins/proposal.md)).

| Type            | What it is                                                                                                                                                    |
| :-------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Skin`          | `system`, `dracula`, `oneDark`, `catppuccin`, `nord`. Its `shape`, `typeface`, `barHeight`, `cardRadius` and `fillsCard`; `palette(for:)` is nil for System.  |
| `SkinPalette`   | The colours of a skin in one appearance, as `0xAARRGGBB`: panel, card, track, text, secondary text, accent, plenty, middle, low, tick and an optional border. |
| `BarShape`      | `pill`, `blocks`, `line`, `thick`, `outline`.                                                                                                                 |
| `Snapshot.skin` | The skin the app chose, written when it publishes so the widget draws the same. A snapshot without one, or with an id this version does not know, is System.  |

The views that draw them are in `Shared/Skins/`: `SkinStyle` (the style in the environment and `skinned(_:)`), `SkinBar` (the five
bars) and `SkinPreview` (the small panel in Settings).

## How the bars read

Left or used, in `Sources/TokenMeterCore/BarsDisplay.swift` and in `BarsDisplayTests.swift`
([ADR 0006](../adr/0006-display-preferences.md), [proposal](../features/2026-11-03-bars-display/proposal.md),
[plan](../features/2026-11-03-bars-display/plan.md)).

| Type                   | What it is                                                                                                                                                                                                                                                                                                                                                                                                  |
| :--------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `BarsDisplay`          | `left` (the default) and `used`. `word` is what follows the figure; `fraction(remaining:)` how far a bar is filled; `percent(remaining:)` the figure; `shown(_:)` the mark; `littleMarginText` and `plentyOfMarginText` the two sentences of the verdict that name a percentage; `figure(remaining:)` the figure with its word, which a notification uses; `markGuide` what the mark means in that reading. |
| `Snapshot.barsDisplay` | The choice the app made, written when it publishes so the widget draws the same. A snapshot without one, or with a value this version does not know, is `left`.                                                                                                                                                                                                                                             |

The data is not touched: a window always stores what is left, and the rest follows it. `percent` is what is left rounded as it always was,
and for `used` a hundred minus that, so the two readings of a window add up to 100. The views read the choice from the environment
(`Shared/BarsDisplayStyle.swift`), and `QuotaBar` takes `emptyIsEmpty` so a window with nothing used is drawn without the smallest fill.

## The welcome

The state of the welcome wizard, in `Sources/TokenMeterCore/Welcome/` and in `WelcomeTests.swift`
([proposal](../features/2026-11-03-welcome-tour/proposal.md), [plan](../features/2026-11-03-welcome-tour/plan.md)).

| Type                  | What it is                                                                                                                                  |
| :-------------------- | :------------------------------------------------------------------------------------------------------------------------------------------ |
| `WelcomeState`        | `idle` or `showing(Page)`. `atLaunch(seen:)` opens at the first page when it was never seen; `applying(_:)` is the transition of an action. |
| `WelcomeState.Page`   | The eight pages in order: `whereItLives`, `bars`, `tick`, `buttons`, `stats`, `suggestion`, `accounts`, `settings`.                         |
| `WelcomeState.Action` | `back`, `next` (Done on the last page), `skip` and `close`. `endedBy(_:)` says whether an action counts as seen.                            |
| `WelcomeSeenStore`    | Whether it was seen: `DefaultsWelcomeSeenStore` in the app, `MemoryWelcomeSeenStore` in tests.                                              |

The window and the pages are in `App/TokenMeter/Welcome/`: an `NSWindow` hosting a SwiftUI view, opened by the app delegate, that uses
nothing of the `Meter`. The pictures are two screenshots of the docs in `Assets.xcassets`; keep them in step with `docs/assets`. The
accounts page draws two of the app's own cards with sample data instead.

## Model limits

A model's limit is a window with a scope ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)).

| Type                              | What it is                                                                                                                                                                         |
| :-------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `WindowSpec.scope`                | A model's name, from the data; `WindowSpec.id` is the name, and the scope after a colon for a scoped window.                                                                       |
| `ReportedQuota.scope`             | The model a reported limit applies to; the builder makes it a window of its own under the one of the same length.                                                                  |
| `ClaudeUsageRefresh`              | `locate`, `run` and `refresh`: ask Claude Code to refresh its usage copy by running its own `/usage`, in an account's folder with `CLAUDE_CONFIG_DIR` when given one.              |
| `ClaudeStatusLine.Account`        | An entry's id and the folder Claude Code reads for it: `setUp`, `otherStatusLine`, `wrap` and `restore` take one ([ADR 0014](../adr/0014-accounts-and-the-home-of-a-provider.md)). |
| `ProviderReading.absent`          | Lengths in minutes of windows the plan lacks, when fresh data says so ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)).                                                   |
| `DisplayPreferences.hiddenModels` | The models of a provider the person turned off; a model is on unless it is here.                                                                                                   |
| `DisplayPreferences.select`       | The windows the person chose: an empty choice is refused, it never hides the provider, and a window just chosen turns its models on.                                               |
| `ProviderConfig.ExistsIf`         | A list that says whether a window exists: `file`, `each`, `where`, `observedAt` and `maxAgeHours` (6 by default).                                                                  |

A quota window in `providers.json` can read a list: `each` (the path to it), `where` (fields an entry must equal), `scope`
(the path of the model's name inside an entry), a `file` of its own and `observedAt` (when the file was fetched). No model is
named in the code.

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
