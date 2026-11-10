# ADR 0002 — The quota model: what a window says and where it comes from

Status: accepted (2026-10-28, consolidated 2026-11-02 from the ADRs on the metric, the Claude quota, reset and stale windows, user-set limits, model limits, windows that exist, the pace and the token count)

## Context

The number that matters is the remaining quota in each limit window (a rolling session, a weekly cap), not tokens. Plan limits
are not expressed in tokens, and neither provider documents a public API for them.

## Decision

**Sources, in order:** local logs (Claude Code `~/.claude/projects/*/*.jsonl`, Codex `~/.codex/sessions/**/rollout-*.jsonl`), and
files the CLIs keep. Browser session cookies are rejected (fragile, against the terms), and so are credentials and
undocumented endpoints ([ADR 0001](./0001-app-architecture.md)). Tokens are secondary context: input plus output, from
local CLI logs only, so not the plan's count.

**A window is `reported`, `reset` or `consumptionOnly`**, and never estimated: there are no user-set limits, because plan
limits are not in tokens and totals are dominated by cache reads.

- **Claude's quota** comes from the status line: `scripts/claude-statusline.sh` copies the JSON Claude Code pipes to it into
  `~/.tokenmeter/claude-statusline.json` ([ADR 0004](./0004-the-claude-status-line.md)), and `rate_limits` gives
  `five_hour` and `seven_day` as `used_percentage` and `resets_at`. It moves only while Claude Code renders. Codex gives both
  of its windows in its logs, and `rate_limits` is `null` for stretches (see known issues).
- **A reported window whose reset time has passed reads as `reset`** (100%, inferred) when nothing was used since; with use
  after the reset it stays `consumptionOnly`. `SnapshotBuilder` makes that choice when it collects, because only it sees the
  tokens; `WindowUsage.resolved(at:)` knows no tokens and turns a reported window whose reset has passed into `reset` at render
  time, until the next collection tells which it is. An exhausted reported window is the exception: its last 0% and known reset
  time remain visible, marked stale after 10 minutes, even after that time passes, until a new quota reading replaces them. The
  interface then says that the reset was expected and an update is pending; it does not claim the quota has renewed. A limit
  for one model is part of the window of the same length and has the same reset time in Claude Code's own data: when that window
  has been reported with a later reset, by at least half its length, the limit ended with it and reads as `reset`, exhausted or
  not, because the renewal is then a fact and not a guess from the clock (`ProviderSnapshot.resolved(_:at:)`). The widget
  timeline has an entry at each reset.
- **A reported figure older than 10 minutes is stale**: kept, dimmed, with a `~`, since use since can only have lowered it.
  Every reported quota carries `observedAt` (the file's modification time for Claude, the event's timestamp for Codex), and the
  snapshot is persisted so a restart shows the last values. A `reset` window is shown with `~` too.
- **A limit can be scoped to a model**, for every provider: `WindowSpec.scope` is an opaque label read from the data, never a
  fixed case. `providers.json` can read a list of limits (`each`, `where`, the paths of `usedPercent`, `resetsAt`, `scope`,
  `observedAt`). Claude keeps a copy of its usage in `~/.claude.json` (`cachedUsageUtilization.utilization.limits`, kinds
  `session`, `weekly_all`, `weekly_scoped`), which tokenmeter reads. Claude Code writes this copy when its interactive `/usage`
  screen opens: **Open /usage** on the card asks Claude Code to do so ([ADR 0015](./0015-claude-model-usage-refresh.md)).
  Claude Code reads its own credentials, tokenmeter never does. A row appears only for a scope that has data.
- **A window exists only if the data lists it.** A provider declares its windows, and a quota window may carry `existsIf`, a
  list in a file. The window is absent when the last known list is readable, not empty and does not name it, even while quota
  percentages grow stale; a newer list can restore it after a plan change. If the list is missing or empty, it stays unknown.
  No plan is named in the code. Claude's 5 hours is absent on the
  Ultra plan.
- **The pace of a window is computed in the core.** At the average since the window began, the quota runs out at
  `start + elapsed / used` if that is before the reset; nothing is estimated unless the figure is reported with a reset time
  ahead, something was used and at least 10% of the window has passed; before that the mark is drawn where the window stands and
  it lasts. The moment is rounded to the hour.
  `WindowUsage.pace(at:)` returns a `Pace` (`aheadFraction`, `runsOutAt`, `isStale`, `runsOut`): the share of the window still
  ahead, measured at `observedAt` for a fresh figure and now for a stale one, which runs out only when the reading is already
  under it. The text the interface says is built in the core too. The panel draws it and the widget does not (`showsPace`); the
  widget gets a short phrase for a fresh figure.
- **A window's tokens are counted in its own period**: from `resetsAt − duration` to now when it has a reset time, and the
  last `duration` otherwise. Totals since the beginning and token statistics are a separate feature.

## Consequences

- A provider that reports no quota shows an empty grey bar and its consumption, never a guess.
- A bar is never blank after an idle spell and never looks more certain than it is; 10 minutes and 10% are choices, not
  measurements.
- The first Claude figure for a model is as old as Claude Code's last usage fetch, and says so.
- The snapshot gains `scope`, `shareOfParent` and the like as optional fields; an older widget ignores them.
- Not verified: a plan that still has the 5 hours, how often Claude Code refreshes its copy in daily use, that other
  providers' data is shaped as a list, and the pace on a ChatGPT window with a real reset time.
