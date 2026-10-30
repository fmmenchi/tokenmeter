# ADR 0034 — Limits can be scoped to a model, for every provider

Status: deferred (2026-10-30), not built: no source reports the figure; extends [ADR 0007](./0007-expired-window-reads-as-reset.md) and [ADR 0015](./0015-provider-contract.md)

## Context

Some plans carry a limit for one model that is **separate from the weekly limit** yet bounded by it. The Claude usage page
shows it as a third row under "This week": the model's name, "Up to 50% of your weekly limit", its own percentage used
(11%) and its own reset time. Today a provider has windows (`5h`, `7d`), each with one remaining fraction, and nothing in
the contract says that a window applies to a model.

**Can it be read from Claude's data? Not today** (checked on this Mac, 2026-10-30):

- The status line gives `rate_limits.five_hour` and `rate_limits.seven_day`, and `spend_limit` behind a gateway. The
  documentation lists no per-model field, and the file tokenmeter keeps has none.
- `~/.claude.json` holds feature flags and prices, no usage figure per model.
- The transcripts carry `rate_limit_info` only on rejected requests, and only of type `seven_day`.
- The figure on the usage page comes from the account's API, which needs the login token. tokenmeter reads no
  credentials and will not start to.

What the logs do carry is **consumption per model**: each assistant message names its model and its tokens.

## Why it is deferred

The thing that was asked for, the model's own **percentage of limit**, cannot be read without the login token, so it
cannot be built. What can be read is consumption per model, which is not the limit and would not answer the question. The
design below stays as the way to do it **when a source reports the figure**, for any model; until then nothing in the app
changes. Reopen it if Claude Code adds a per-model field to the status line.

## Decision

The solution is **cross-model**: no model, provider or plan is named in the common code. A model is data, never a case.

- A window may carry an optional **scope**, an opaque label for the model (or group of models) it applies to, written in
  `providers.json` or read from the provider's data. `WindowSpec` gains `scope: String?`; a window with no scope is the
  provider's own, as today. A scoped window may also carry `shareOfParent` (0 to 1, for "up to 50% of the weekly limit"),
  which is information for the reader, not a calculation.
- A reported quota names its scope when its source does (`ReportedQuota.scope: String?`), and is matched to the window
  with the same scope and duration. Nothing is inferred across scopes.
- **Without a reported figure, a scoped window shows consumption only**: tokens per model in the window, read from the
  logs by an optional `model` path in the provider's `usage` config. It never shows a percentage, as in ADR 0007: the
  cap is the plan's rule and is not in the data.
- Rows appear only for scopes that have data (a reported figure or consumption). The app does not list models, and an
  empty row is never drawn.
- Every provider, in `providers.json` or in Swift, can declare scoped windows the same way. When Claude Code or another
  tool starts to report a per-model figure, adding it is a line of configuration (a `scope` and a path), not code.

## Consequences

- The snapshot gains `scope` and `shareOfParent` on a window, absent from older files; an older widget ignores them.
- The bar of a scoped window sits under its parent and reads against the parent's reset unless it has its own.
- Until a source reports it, the Fable-style row is **consumption only** for Claude: tokens per model, no bar and no
  percentage. The percentage on the usage page cannot be shown without reading credentials.
- Not decided here: how it looks (a proposal first, [ADR 0032](./0032-a-features-section-groups-proposal-plan-and-decisions.md)),
  and whether to ask Anthropic to expose per-model limits in the status line.
- Not verified: that an assistant message in every provider's logs names its model; Claude's do, ChatGPT's were not checked.
