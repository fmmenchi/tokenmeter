# ADR 0005 — Claude plan quota from the status line

Status: accepted (2026-10-28)

## Context

ADR 0002 left Claude's remaining quota open: the transcripts carry tokens, not plan limits. The
`claude` binary documents a status-line input with `rate_limits.five_hour` and
`rate_limits.seven_day`, each `{ used_percentage, resets_at }`, present only while the API reports
the window and its `resets_at` has not passed.

## Decision

- A `statusLine` command (`scripts/claude-statusline.sh`) copies the JSON Claude Code pipes to it
  into `~/.tokenmeter/claude-statusline.json` and prints a short line.
- `ClaudeQuotaReader` reads `rate_limits` from that file and returns one `ReportedQuota` per
  window; the snapshot marks those windows `reported`.
- The reader ignores a window whose `resets_at` has passed.
- Rejected: calling the OAuth usage endpoint with the token Claude Code keeps in the Keychain. It
  works, but it means handling a credential and an undocumented API from a background app.

## Consequences

- The file only updates while Claude Code is running and rendering its status line. Between
  sessions the last values stand until their `resets_at`, then the window falls back to
  `consumptionOnly` or an estimate.
- Installing it edits the user-level `~/.claude/settings.json` `statusLine`; an existing status
  line must be wrapped, not replaced.
- Codex gets the same treatment: both `primary` and `secondary` windows are read from its logs.
