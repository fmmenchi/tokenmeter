# ADR 0009 — Remove user-set token limits

Status: accepted (2026-10-28)

## Context

ADR 0002 and ADR 0003 gave the app a Limits window where the user typed a token budget per
provider and window, so a bar could be estimated when no provider reported a quota. Both
providers now report their quota (ADR 0005, ADR 0007), so the estimate never runs. Plan limits
are not published in tokens and totals are dominated by cache reads, so there is no sensible
number to type. The window also did not open from the menu-bar app.

## Decision

Remove the Limits window, `LimitSettings`, `WindowSpec.tokenLimit` and the `estimated` source.
A window is `reported`, `reset` (inferred) or `consumptionOnly`. The sections of ADR 0002 and
ADR 0003 that describe user-set limits are superseded by this ADR.

## Consequences

- A provider that reports no quota shows an empty grey bar and its consumption, never a guess.
- If a provider without any quota source is added later, an estimate needs a new ADR.
- Snapshots written earlier still decode: unknown keys are ignored.
