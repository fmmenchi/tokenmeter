---
title: Data Sources
sidebar_label: Data Sources
sidebar_position: 1
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
`~/.tokenmeter/claude-statusline.json`, and `ClaudeQuotaReader` reads the two windows from it. See
[ADR 0005](../adr/0005-claude-quota-from-statusline.md).

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

## Why not ask the providers

Calling the OAuth usage endpoint with the token Claude Code keeps in the Keychain would keep the
numbers fresh, but it means a background app handling a credential and an undocumented API. It was
rejected in [ADR 0006](../adr/0006-no-polling-of-provider-endpoints.md); it would need its own
decision to revisit.

## How often it reads

The app re-reads every 60 seconds and whenever the panel opens. Reading is incremental: each log
file is parsed once and only the bytes added since are read afterwards
([ADR 0004](../adr/0004-incremental-log-scanning.md)). The first read after launch scans a week of
logs and took about 9 seconds for 7.5 GB; it runs off the main thread.

## Related

- [Enable the Claude Quota](../guides/enable-claude-quota.md)
- [Reading the Bars](./bars.md)
