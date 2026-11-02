# ADR 0010 — The usage store: facts the app has seen, and statistics drawn only from them

Status: accepted (2026-11-02, with the plan of the [usage stats](../features/2026-11-02-usage-stats/plan.md); Fabio asked to carry the feature to the end)

## Context

The app holds the last reading and re-reads logs that the CLIs keep for a while: Claude Code prunes its own, and the oldest
log on the author's Mac is a month old, Codex's a week. Nothing says how a window ended, or which models used the tokens, once
a log is gone. The statistics need a past, and the past can only be kept by writing it down when it is seen.

Checked on 2026-11-02 against the author's files, reading only field names, dates and numbers:

- Claude's logs repeat each message: 127,180 lines with tokens for 59,237 messages. The app already removes the repeats
  (`dedupeBy`, [ADR 0003](./0003-providers-in-one-config-file.md)).
- Claude's quota percentage is not in its logs, except as a refusal when a limit is hit. The app already asks Claude Code to
  run `/usage` every 15 minutes ([ADR 0002](./0002-quota-model-and-data-sources.md)), which rewrites `~/.claude.json` with the
  percentages of the whole account and the time of the reading.
- Codex's logs carry `rate_limits` with the percentage of each window, and it never went down inside a window in 4,904 readings.
- Tokens counted from the logs did not follow the percentage of a window (from 0.000 to 0.054 M tokens per point on the
  5-hour window), because the quota is the account's and the logs are one Mac's.

## Decision

- **A small SQLite file keeps facts**, in `~/Library/Application Support/TokenMeter/usage.sqlite`, written by the app only
  and never read by the widget. A fact is something that was measured or counted, with its provider and its time, and the
  store holds **nothing derived and nothing estimated**.
- **Two kinds of fact.** A _message_: provider, a key that is unique for the provider, the time, the model when the source says
  it, and the four token counts. A _reading_: provider, window length, what the limit applies to, the time the window resets,
  the highest percentage used seen in it, and when it was first and last seen, with where it came from. Both are inserted
  with a unique key and ignored when present, so reading the same file twice or the same window twice changes nothing; a
  reading keeps the highest percentage, because a window's percentage does not go down.
- **The source is not part of a fact's identity.** Another collector, an API for the quota for instance, adds facts of
  the same two kinds and changes nothing downstream. A collector that cannot say a fact (a source with no model) leaves it empty.
- **The collectors are the ones that exist** (`ConfiguredSource`, [ADR 0003](./0003-providers-in-one-config-file.md)), made to
  say more: the model of a message and the key that identifies it, read from paths in `providers.json`, and every
  reading of a window the log carries, not only the last. The collector for the snapshot is not changed, and a second set of the
  same sources, the ingestor's, reads **all** the files once at launch and then what is new, off the main thread and after the
  snapshot, so the panel never waits for the store.
- **One writer, off the main thread.** The store serialises its calls, uses the write-ahead log and a busy timeout. The panel
  reads through the same object. The Claude status line script does not change and never touches the store.
- **Statistics are pure functions of the facts** (`UsageStats`): the windows that closed, whether the ceiling was hit (100%),
  the quota left at the end as _at least_ what was seen, and the share of each model family. The same facts give the same
  figures, which is what the tests check. A window with no reading is **not observed** and is not drawn, and a figure that
  would need an estimate is not offered: no size of a plan in tokens, no verdict from tokens.
- **A model is shown by family**, from rules in `providers.json` (a fragment of the name and the family it means), so a new
  model does not need a release; without a rule the raw name is shown. `<synthetic>` is not a model. Versions of a family add up.
- **A new field of `providers.json`** (`usage.model`, `usage.families`) reaches a file that already exists by a migration,
  added once, only when absent, with the original kept as `.bak`, like the one that added the Claude integration.
- **The store is not a backup of the logs.** It can be rebuilt from the logs for tokens, as far as they go, and not for
  quota readings, which exist only as seen. A missing or unreadable file is made again empty, and the app, the snapshot and the
  widget work without it.

## Consequences

- The past of a statistic starts the day the app first runs this version, plus what the logs still hold. A month of Claude
  and a week of Codex at the start, in the author's case. A window the app did not see is shown as not observed.
- Readings come from the whole account (the percentage), and tokens from this Mac (the logs). The panel says which is which.
- The first read of every file costs time that was not measured; it runs once, off the main thread.
- A fact cannot be corrected by the provider afterwards: what was seen is what is kept. A model with no rule shows its raw name.
- A migration touches the user's `providers.json` again, the same way as before.

## Not verified

- SQLite from the system library in Swift 6 with the write-ahead log, in this package and in the app.
- How long the first read of a month of logs takes, and how much memory the ingestor's copy of the sources holds.
- That the percentage in `~/.claude.json` is refreshed when Claude Code is not otherwise open: the app asks for it, and the
  outcome is logged but was not checked against a long run.
- A window of Codex that spans two files with the same resets time: the highest percentage wins, which was not tested on real
  logs.
