# Known issues — agent rules

Read this **before** debugging something odd. Each entry: symptom, cause, what to do.

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
