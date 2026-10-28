# ADR 0007 — An expired reported window reads as reset

Status: accepted (2026-10-28)

## Context

Provider quotas arrive with a `resets_at`. When it has passed and no newer value was logged,
the old code dropped the quota and showed "unknown". For a rolling window that was not used since,
that is misleading: the window has reset and is full.

## Decision

`SnapshotBuilder` marks a window `reset` (remaining 100%) when all of these hold:

- a reported quota for that window length exists and its `resets_at` has passed;
- no tokens were recorded in the window, so there was no use that a missing log line could hide.

If tokens were recorded after the reset, the window stays `consumptionOnly`: the quota is
genuinely unknown, not full. `reset` is shown as inferred, never as reported.

## Consequences

- ChatGPT/Codex and Claude bars are full after an idle period instead of empty.
- If a provider changes its windows without telling the logs, the inference can be wrong until the
  next real value arrives.
