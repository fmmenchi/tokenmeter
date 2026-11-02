# ADR 0003 — Providers are declared in one config file, and the common code names none

Status: accepted (2026-10-29, consolidated 2026-11-02 from the ADRs on the provider contract, the config file and its seed)

## Context

Claude and ChatGPT reached the snapshot by different roads, with a field and hand-written glue for each, so a third provider
meant editing the enum, the collector, the snapshot, the panel and the probe. The requirement is that all providers are
treated the same, and configurable without recompiling.

## Decision

- **Some things are the same for every provider and the app owns them** (the window maths, the bars, the refresh cadence, the
  snapshot and the widget timeline). A provider declares only what is its own: `ProviderInfo` (id, title, windows, an optional
  `setupHint`) and a `ProviderReading` (usage events, reported quotas, the plan label, `quotaUpdatedAt`). `Provider` is a
  string-backed id, not an enum.
- **`~/.tokenmeter/providers.json` is the only list of providers, and every entry is equal.** On first run, if it is missing, the
  app writes it with Claude and ChatGPT (the seed, `DefaultProviders.swift`); on every run the providers are exactly the
  file's entries, in its order, with no merge or override. A file that cannot be used (broken JSON, unknown version, a
  repeated id) is not overwritten: the seed is used for that run and the probe says why. The file belongs to the user once
  written, and `version` is where a migration would hook.
- **The format is JSON with dotted paths and nothing else**: no expressions, no scripting, and it names files to read, never
  commands. `log` (a folder of `.jsonl`, a byte filter `contains`, `where`, `timestamp`), `usage` (`perEvent`, optionally
  deduplicated by `dedupeBy`, or `cumulative`, an event being the positive difference to the previous line), `quota` and `plan`
  (from a `file` or from the log lines, the latest by timestamp winning; `plan.labels` is an ordered list of rules, `plan.stripPrefix`
  and a capitalised fallback), `windows` as lengths in minutes. `~` is relative to a home directory the source is given.
- **The native readers are gone**: every provider is a `ConfiguredSource` over the shared `LogFiles` scanning. A provider whose logs
  need more than equality, `contains` and one subtraction is a `ProviderSource` in Swift, and the protocol stays for it.
- **One narrow, additive migration**: if the file has a `claude` provider without an `integration` key, the app adds
  `"integration": "claude-status-line"`, after saving `providers.json.tokenmeter.bak`. A key already there, whatever its value, is
  never touched, and neither is a file that is not the expected JSON.

## Consequences

- A provider whose logs fit the shape needs no code and no rebuild. Measured on real Claude logs (7 days, 7.5 GB) the config
  and the old native reader gave 19,600 events and identical totals, within a few seconds of each other; `dedupeBy` merges by
  `message.id` even when `requestId` is missing, which is what made the first comparison differ by nine events.
- Overriding a provider means writing its entry whole; there is no partial patch.
- The file is written back as JSON with two-space indentation and keys sorted, so its layout may change once.
- The app writes a file in the user's home on first run; it is not sandboxed, so no new permission is involved.
- Not verified: the migration on a file edited by hand with unusual formatting, beyond the tests.
