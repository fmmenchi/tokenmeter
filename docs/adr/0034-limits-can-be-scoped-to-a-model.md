# ADR 0034 — Limits can be scoped to a model, for every provider

Status: proposed (2026-10-30), reopened: Claude Code's own `/usage` gives a fresh figure without tokenmeter handling a credential; extends [ADR 0007](./0007-expired-window-reads-as-reset.md), [ADR 0015](./0015-provider-contract.md) and [ADR 0016](./0016-providers-declared-in-a-config-file.md)

## Context

Some plans carry a limit for one model that is **separate from the weekly limit** yet bounded by it. The Claude usage page
shows it as a row under "This week": the model's name, "Up to 50% of your weekly limit", its own percentage used and its
own reset time. Today a provider has windows (`5h`, `7d`), each with one remaining fraction, and nothing in the contract
says that a window applies to a model.

**It can be read from Claude's data, but not from the status line** (checked on this Mac, 2026-10-30):

- The status line gives only `rate_limits.five_hour` and `rate_limits.seven_day`. The documentation lists no per-model
  field.
- Claude Code keeps a **copy of the usage response in `~/.claude.json`**, under `cachedUsageUtilization`. Its code writes
  it whenever it fetches usage, at most once per interval. In it, `utilization.limits` is a list, one entry per limit:
  `kind` (`session`, `weekly_all`, `weekly_scoped`), `group`, `percent`, `resets_at`, `severity`, and for a scoped one
  `scope.model.display_name` (and a `scope.surface`). `weekly_scoped_shares` gives its allowance as a percent of the
  weekly limit and `limit_index` points at the entry. The same object has `seven_day_opus`, `seven_day_sonnet` and others.
  The list shape is not tied to any model: a new model is a new entry, not a new field.
- The open-source menu-bar app [OpenUsage](https://github.com/robinebers/openusage) reads the same list from the live endpoint
  (`GET /api/oauth/usage` with an OAuth bearer token) and picks a model's row from `limits` by
  `kind = weekly_scoped` and `scope.model.display_name`. Its code notes that the old fixed keys (`seven_day_<model>`) now
  return null, so the list is the only reliable shape. It needs a token with the `user:profile` scope, which it obtains with
  its own sign-in; the endpoint is undocumented.
- `fetchedAtMs` says when it was written. On this Mac it is **15 October, 15 days old**, so the copy is only as fresh as
  Claude Code's last fetch, and nothing in the status line refreshes it.
- It reads no credential: it is a cache of figures, and tokenmeter already reads another part of the same file for the
  plan ([ADR 0012](./0012-show-the-plan-name.md)).

## Why it is possible after all

The first verdict was that the figure could only be fresh with a login token. That was wrong. Claude Code fetches and
writes the usage copy itself whenever it runs `/usage`, and `/usage` works non-interactively:

- `claude -p "/usage"` prints the session, the week and each model's week ("Current week (Fable): 13% used"), and refreshes
  `cachedUsageUtilization` in `~/.claude.json`. Claude Code reads its own credentials; tokenmeter never sees them.
- Measured on this Mac: about 5 seconds; with `--no-session-persistence --no-chrome` the CPU drops from about 15 seconds to
  about 4. The write is throttled to one a minute, and without `--no-session-persistence` each run leaves a session file.
- It is not a model call: it printed figures and no answer, and the run left no request in the account's own count (not
  verified against the plan's usage).

So tokenmeter can ask Claude Code for the figure and read the structured list, instead of waiting for the person to open
`/usage`. The API stays out: no sign-in, no token, no client identity.

The API was considered as an opt-in setting for the per-model rows and dropped. Its sign-in needs a client identity
tokenmeter does not have; the open-source app that does this uses Claude Code's own client id (found in Claude Code's
binary) and a `claude-cli` user agent, which is impersonation. Fabio decided to leave the API alone; asking Claude Code to do it is not that.

## Decision

The solution is **cross-model**: no model, provider or plan is named in the common code. A model is data, never a case.

- A window may carry an optional **scope**, an opaque label (the model's display name, or a surface) read from the data or
  written in `providers.json`. `WindowSpec` gains `scope: String?`; a window with no scope is the provider's own, as today.
  A scoped window may carry `shareOfParent` (0 to 1) for "up to 50% of the weekly limit": information, not a calculation.
- A reported quota names its scope when its source does (`ReportedQuota.scope`), and is matched to the window of the same
  scope and duration. Nothing is inferred across scopes.
- **`providers.json` can read a list of limits.** A quota window may say `each` (a path to a list), `where` (fields that
  must equal values, as the log rules already do), and the paths of `usedPercent`, `resetsAt`, `scope` inside each entry,
  plus where to read when it was observed (`observedAt`, in epoch milliseconds). For Claude that is `limits` where `kind`
  is `weekly_scoped`. Any provider that reports a list of limits is declared the same way.
- **Rows appear only for scopes that have data.** The app does not list models and never draws an empty row.
- **Freshness is shown, not hidden**, by the rules that exist: a figure older than ten minutes reads `~` and its bar is
  dimmed ([ADR 0008](./0008-remember-last-quota-and-flag-stale.md)), and one whose reset time has passed reads as reset
  ([ADR 0007](./0007-expired-window-reads-as-reset.md)).
- Without any figure for a model, nothing is shown for it. Consumption per model, which the logs also carry, is not the
  limit and is not part of this decision.

## Consequences

- **A refresh is a run of `claude`**: only on demand and on a slow timer (not every minute), in a folder of its own
  (`~/.tokenmeter/claude/`), with `--no-session-persistence --no-chrome`, and only when the app can find the CLI. Where it
  cannot, or it fails, the figure stays as old as the copy and says so (ADR 0008). The cadence and the lookup of the CLI
  are for the plan.

- The snapshot gains `scope` and `shareOfParent` on a window, absent from older files; an older widget ignores them.
- The first Claude bar for a model is as old as Claude Code's last usage fetch. On this Mac that is far older than a
  reset period, so it would read as a reset. Showing it honestly is the point; making it fresher would mean fetching
  usage ourselves, which needs an OAuth token on an undocumented endpoint. tokenmeter does not do that: it reads no
  credentials and has no sign-in of its own. If that is ever wanted it is a separate ADR.
- Joining `weekly_scoped_shares` (the "up to 50%") by `limit_index` is not in the list-reading rule above and is left to
  the design: either a second field read by position, or omitted in the first version.
- Not decided here: how it looks (a proposal first, [ADR 0032](./0032-a-features-section-groups-proposal-plan-and-decisions.md)).
- Not verified: how often Claude Code refreshes the copy while in daily use (it is 15 days old on this Mac), and that
  other providers' data is shaped as a list.
