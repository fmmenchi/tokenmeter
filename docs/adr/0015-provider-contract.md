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

Every provider implements one protocol, and the list of providers is declared once.

```swift
public protocol ProviderSource: Sendable {
    var provider: Provider { get }
    var windows: [WindowSpec] { get }
    func read(since: Date) -> ProviderReading
}
```

- **`ProviderReading`** is the whole answer of a source: usage `events`, provider-`quotas`, the
  `plan` label, when the quota was last `quotaUpdatedAt`, and a `setupHint` shown while no quota has
  been seen (Claude's status-line instruction lives there, not in the panel).
- **`Providers.standard`** (`Sources/TokenMeterCore/Providers.swift`) is the one list. Adding a
  provider is a source type plus one line in that list; `Collector`, the probe and the panel iterate
  it and do not name a provider.
- **Symmetric:** no provider has a field of its own. `quotaUpdatedAt` and `setupHint` move from
  `Snapshot` and the panel into `ProviderSnapshot`, so ChatGPT can use them too.
- **`Provider` is an id, not an enum.** A string-backed struct with `.claude` and `.chatgpt`
  constants, encoded exactly like the old enum (`"claude"`), so a new provider needs no change to
  the type. Its display name travels in `ProviderSnapshot.title`; the widget has no registry.

A contract for providers outside the app (a file format an external script writes, like the Claude
status line does) is not part of this decision. It needs a provider that needs it first.

## Consequences

- `snapshot.json` written by the previous build still decodes: the new fields are optional and the
  title falls back to the provider id. The removed `claudeQuotaUpdatedAt` is ignored.
- `SnapshotBuilder` keeps its signature; sources only feed it, so the window and reset rules
  (ADR 0007, 0008) are untouched.
- A source reads its own files. Adding a provider whose logs carry no usage still needs a reader;
  the contract only fixes where that reader plugs in.
