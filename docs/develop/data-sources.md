---
title: Data Sources
sidebar_label: Data Sources
sidebar_position: 5
---

# Data sources

tokenmeter has no network access of its own and holds no credentials. Everything comes from files
the two CLIs leave on your machine.

| Provider | Quota (percent left, reset time)       | Tokens                          |
| -------- | -------------------------------------- | ------------------------------- |
| Claude   | `~/.tokenmeter/claude-statusline.json` | `~/.claude/projects/**/*.jsonl` |
| ChatGPT  | `~/.codex/sessions/**/rollout-*.jsonl` | the same Codex logs             |

## Claude

**Quota.** Claude Code pipes a JSON document to its status-line command. When the API reports the
limits, it contains `rate_limits.five_hour` and `rate_limits.seven_day`, each with
`used_percentage` and `resets_at`. `scripts/claude-statusline.sh` saves that document to
`~/.tokenmeter/claude-statusline.json`, and the Claude entry of `providers.json` reads the two windows from it. See
[ADR 0002](../adr/0002-quota-model-and-data-sources.md).

The file is only rewritten while a Claude Code session is rendering its status line. Between
sessions the last values stay, and the panel shows how old they are.

**Tokens.** Each assistant message in the transcripts carries a `usage` object. A streamed
message is logged several times with growing counts, so only the last entry per message is kept.

## ChatGPT

ChatGPT's plan limits are read from the **Codex CLI** logs, so only Codex use is seen. Each
`token_count` event carries cumulative counters and, when the service reports it, a `rate_limits`
object with a `primary` window (300 minutes, the 5h window) and a `secondary` window (10080
minutes, the weekly one). Cumulative counters are turned into per-event deltas, and the latest
value of each window is kept.

`rate_limits` is `null` in many events, and some carry a different `limit_id` with no windows; those
are skipped.

## What is not seen

- Use on claude.ai or chatgpt.com, in the web or desktop apps: there is no local trace of it.
  Token counts therefore undercount your real use, and so can the quota between sessions.
- Any other Claude Code or Codex installation on another machine.

## What the app keeps

The logs are not the only past. The CLIs prune theirs, and Claude's quota percentage is in none of them, so the app writes what
it sees into a small SQLite file, `~/Library/Application Support/TokenMeter/usage.sqlite`
([ADR 0010](../adr/0010-the-usage-store.md)), and the stats are drawn from that file only.

| Fact    | Holds                                                                                                                     | Comes from                                                                       |
| :------ | :------------------------------------------------------------------------------------------------------------------------ | :------------------------------------------------------------------------------- |
| Message | provider, a key that is unique for the provider, time, the model when the log says it, four counts                        | the usage lines of the logs, with the same `dedupeBy` as the bars                |
| Reading | provider, window length, what it applies to, time of reset, the highest percentage seen, first and last time seen, source | the windows a log reported (Codex), and the status line and usage copy of Claude |

Both are inserted under their key and ignored when present, so a second read, a restart or another copy of the app adds nothing,
and a reading keeps the highest percentage because a window's percentage does not go down. Nothing derived and nothing estimated is
stored.

How far back it goes is what the logs still hold the first time the app runs this version, and from then on what the app saw.
On the author's Mac, on 2026-11-02, Claude's logs went back to 2026-07-10 (81,929 messages, with the model on each) and Codex's to
2026-10-26 (2,435 messages, the model taken from the line that opens each turn). Claude's quota was kept from that day only.

The first pass reads every log file once: 1,304 files, 7.4 GB, about 95 seconds of one core, off the main thread, with the
memory of the app staying around 240 MB because a file is read in chunks and each line is decoded in a pool of its own. The
passes after it look back two days and read only the bytes added.

## Why not ask the providers

Calling the OAuth usage endpoint with the token Claude Code keeps in the Keychain would keep the
numbers fresh, but it means a background app handling a credential and an undocumented API. It was
rejected in [ADR 0001](../adr/0001-app-architecture.md); it would need its own
decision to revisit.

## How often it reads

The app re-reads every 60 seconds and whenever the panel opens. Reading is incremental: each log
file is parsed once and only the bytes added since are read afterwards
([ADR 0001](../adr/0001-app-architecture.md)). The first read after launch scans a week of
logs and took about 9 seconds for 7.5 GB; it runs off the main thread. The history is read by an ingestor with sources of
its own, after the snapshot, so the panel never waits for it (see above).

## Related

- [Enable the Claude Quota](../use/enable-claude-quota.md)
- [Reading the Bars](../use/bars.md)
