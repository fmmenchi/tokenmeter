# ADR 0008 — Remember the last quota and flag it when stale

Status: accepted (2026-10-28)

## Context

Both quotas are only observed while the provider's CLI runs (ADR 0005, ADR 0002). Between
sessions the last value is the best information there is, but showing it like a live reading
overstates what is known: usage since then can only have raised it.

## Decision

- Every reported quota carries `observedAt`: the status-line file's modification time for Claude,
  the log event's timestamp for Codex. The snapshot keeps it per window.
- A reported quota older than 10 minutes is **stale**. The UI keeps showing it, dimmed, with a
  `~` before the figure and the text "last seen 3h ago, may be higher now".
- A `reset` window (ADR 0007) is dimmed and shown with `~` as well: it is inferred.
- At render time `WindowUsage.resolved(at:)` turns any reported figure whose `resets_at` has passed
  into a full, inferred `reset` window and drops its observation. The widget timeline gets an
  entry at each upcoming reset so the flip happens on time, not at the next refresh.
- The snapshot is persisted by the host app (App Group), so a restart still shows the last values.

## Consequences

- The bar is never blank after an idle spell, and never looks more certain than it is.
- 10 minutes is a heuristic; it is a constant in `Shared/UsageViews.swift`.
