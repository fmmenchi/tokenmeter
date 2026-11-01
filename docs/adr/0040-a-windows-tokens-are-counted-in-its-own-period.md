# ADR 0040 — A window's tokens are counted in its own period

Status: proposed (2026-11-01); corrects the count of [ADR 0002](./0002-metric-and-data-sources.md) for a window whose
provider gave its reset time

## Context

The line under a bar says "input + output tokens seen in that window". The code counts the events of the last `duration`
before now, a rolling period, in `SnapshotBuilder.providerSnapshot`. While the provider's window and the rolling period
begin together, nothing shows. When the provider moves the boundary, they do not: on 2026-11-01 Codex wrote a weekly window
that began on 2026-10-29 with 0% used, while the line said 9.9M tokens, which are the tokens since 2026-10-26. Counted from
the start of that window they were 24,671 (counted by hand from the Codex logs, not by the app). The bar and the number were
from two different periods, and the number could not be reconciled with the bar.

## Decision

**A window with a reset time counts its tokens from `resetsAt − duration` to now: its own period.** That is the period the
percentage is about.

- **Without a reset time** (consumption only, or a figure with no `resetsAt`) the count stays the last `duration` before
  now, since nothing says where the period began.
- **A window that was reset** (ADR 0007) has no tokens counted: nothing was used since, as before.
- **A model's limit** has no count, as before (ADR 0034).
- **The read of the logs does not change**: it already goes back a week, and a period that has a reset time ahead begins
  after that.
- **It is computed, not stored**, in `TokenMeterCore`, and tested without the interface.

## Consequences

- **The numbers under the bars change** wherever a provider's window began later than the rolling period: they are
  smaller, and they agree with the bar. For Claude, whose weekly window the provider also moves, the same.
- **They are still not the plan's count** (ADR 0002): input and output only, from local CLI logs.
- The Tokens section of the Bars page of the docs says "the last N hours or days" in one case and "since the window began" in
  the other.

## Open

- Whether a window whose figure is old, but whose reset time is still ahead, should count from its start. It does here: the
  reset time is the only thing that says where the period began.
