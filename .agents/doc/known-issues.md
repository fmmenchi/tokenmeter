# Known issues — agent rules

Read this **before** debugging something odd. Each entry: symptom, cause, what to do.

## A preview from a worktree says "The widget's data could not be written"

**Symptom:** `./scripts/preview.sh` run in a git worktree opens a build whose panel lists "The widget's data could not be
written: you don't have permission to save snapshot.json in the folder tokenmeter".
**Cause:** `Local.xcconfig` is git-ignored, so a worktree has none; without `DEVELOPMENT_TEAM` the App Group of the build is
`tokenmeter` with no team prefix, and macOS refuses that container (it still creates an empty `~/Library/Group Containers/tokenmeter`).
**Do:** copy `Local.xcconfig` from the main checkout into the worktree and run the preview again. The feature is not at fault.

## Codex `rate_limits` is mostly `null`

**Symptom:** the probe shows `reported quota: none`, or a stale percentage (e.g. 99% used).
**Cause:** `token_count` events carry `rate_limits: null` in many rollouts; the last non-null
value may belong to a window that has since reset.
**Do:** `SnapshotBuilder` already drops a reported quota whose `resetsAt` is in the past. Keep it.

## Token totals are dominated by cache reads

**Symptom:** a 5h window shows hundreds of millions of tokens.
**Cause:** `cacheRead` is counted on every turn. It measures traffic, not plan consumption.
**Do:** show input/output separately; do not present the total as "quota used".

## `swift build` needs a Sendable-clean date parser

`ISO8601DateFormatter` is not `Sendable` under Swift 6 language mode. Use
`Date.ISO8601FormatStyle` (see `Dates.swift`), not a shared static formatter.

## pnpm blocks dependency build scripts

`pnpm install` fails with `ERR_PNPM_IGNORED_BUILDS` for a new package with a postinstall.
Decide in `pnpm-workspace.yaml` under `allowBuilds`; do not approve blindly.

## Claude quota is only as fresh as the last status-line render

`~/.tokenmeter/claude-statusline.json` is written by `scripts/claude-statusline.sh`, which runs only
while Claude Code renders its status line (ADR 0002). If the bars for Claude are empty, check that
`statusLine` in `~/.claude/settings.json` points at the script and that a session has run since.

## A first scan is slow

The first collection after launch reads every log touched in 7 days (about 9 s for 7.5 GB, release
build). Later refreshes read only appended bytes (ADR 0001). Do not call the readers on the main thread.
