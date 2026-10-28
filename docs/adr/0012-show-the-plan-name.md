# ADR 0012 — Show the plan name

Status: accepted (2026-10-28)

## Context

The bars say how much is left but not of which plan, and a Max 20x and a Pro account read very
differently at the same percentage. Both CLIs already record the plan locally.

## Decision

- **ChatGPT:** `plan_type` in the `rate_limits` object of the Codex logs (`team`, `plus`, `pro`, ...).
- **Claude:** `organizationType` and `organizationRateLimitTier` under `oauthAccount` in
  `~/.claude.json` (`claude_max` with `default_claude_max_20x`).

The readers decode **only those fields**; the profile also holds an email, a name and identifiers,
and none of them are read into the snapshot. `PlanName` turns the raw values into a label
("Max 20x", "Team") and falls back to the capitalized raw value for plans it does not know. The
label sits next to the provider name, and is omitted when no plan was found.

## Consequences

- `~/.claude.json` is not a documented interface; if the fields move, the label disappears and
  nothing else breaks.
- The plan can be stale: it is the last one the CLI wrote.
