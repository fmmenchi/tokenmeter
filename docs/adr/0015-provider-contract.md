# ADR 0015 — One contract for every provider, declared in one place

Status: accepted (2026-10-29)

## Context

Claude and ChatGPT reached the snapshot by different roads. `Collector` had a field per reader
(`claude`, `codex`, `claudeQuota`, `claudePlan`) and hand-written glue for each provider. Claude
used three readers (events, quota, plan), Codex one. `Snapshot` carried `claudeQuotaUpdatedAt`,
the panel hard-coded the Claude status-line hint, and `Provider.title` was
`self == .claude ? … : …`. A third provider would have meant editing the enum, `Collector`, the
snapshot, the panel and the probe.

## Decision

Some things are the same for every provider and the app owns them; some belong to one provider and
the provider declares them. The contract is only the second kind.

**Common, owned by the app** (no provider touches these):

- the window maths: tokens per window, reported / reset / consumption-only, the stale threshold
  ([ADR 0007](./0007-expired-window-reads-as-reset.md), [0008](./0008-remember-last-quota-and-flag-stale.md));
- the bars, colour thresholds, `~` marker and panel layout;
- the refresh cadence, the snapshot and the widget timeline.

**Per provider, declared by a `ProviderSource`:**

```swift
public protocol ProviderSource: Sendable {
    /// Constant: who it is and what it shows.
    var info: ProviderInfo { get }
    /// Dynamic: what its files say now.
    func read(since: Date) -> ProviderReading
}
```

- **`ProviderInfo`** (constants): the `provider` id, its `title`, the `windows` it has (5h and 7d
  today) and an optional `setupHint`, the line shown while no quota has been seen. Claude's
  status-line instruction lives there, not in the panel.
- **`ProviderReading`** (per read): usage `events`, provider-reported `quotas`, the `plan` label and
  `quotaUpdatedAt`. How a source finds and parses its files is its own business.

**One place:** `Providers.standard` (`Sources/TokenMeterCore/Providers.swift`) is the only list.
Adding a provider is a source type plus one line there; `Collector`, the probe and the panel iterate
it and do not name a provider.

**Symmetric:** no provider has a field of its own. `quotaUpdatedAt` and `setupHint` leave
`Snapshot` and the panel for `ProviderSnapshot`, so ChatGPT can use them too.

**`Provider` is an id, not an enum:** a string-backed struct with `.claude` and `.chatgpt`
constants, encoded exactly like the old enum (`"claude"`), so a new provider needs no change to the
type. The title and hint travel in `ProviderSnapshot`; the widget has no registry.

A contract for providers outside the app (a file format an external script writes, like the Claude
status line does) is not part of this decision. It needs a provider that needs it first.

## Consequences

- `snapshot.json` written by the previous build still decodes: the new fields are optional and the
  title falls back to the provider id. The removed `claudeQuotaUpdatedAt` is ignored.
- `SnapshotBuilder` keeps its signature; sources only feed it, so the window and reset rules
  (ADR 0007, 0008) are untouched.
- A source reads its own files. Adding a provider whose logs carry no usage still needs a reader;
  the contract only fixes where that reader plugs in.
