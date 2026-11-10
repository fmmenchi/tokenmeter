# ADR 0015 — Refresh Claude model limits through its interactive Usage screen

Status: accepted (2026-11-08), amended 2026-11-10: the background run is back

## Context

The weekly and session quota comes from Claude Code's status line, but a model-specific weekly limit comes from
`cachedUsageUtilization` in Claude Code's own `~/.claude.json` ([ADR 0002](./0002-quota-model-and-data-sources.md)).
tokenmeter has run `claude -p "/usage" --no-session-persistence --no-chrome` every 15 minutes and on panel refresh.
With Claude Code 2.1.319 this command exits zero, prints an empty session summary, and leaves `fetchedAtMs` unchanged. The
problem banner correctly detects the missing data but calls the exit a Claude Code failure. In a terminal, `claude /usage
--no-chrome` opens the Usage screen and updates the cache, including the model-specific limit.

## Decision

- Stop running `/usage` in print mode on a timer or on panel refresh. The panel's refresh still collects the status line and
  reads any model limits Claude Code has written.
- Show when the model-specific limit was last observed beside its row. Keep the stale mark on its figure.
- Offer **Open Claude usage** on a Claude card. The action opens Terminal with an interactive `claude /usage --no-chrome`
  command in that account's own folder, with `CLAUDE_CONFIG_DIR` set for a named account. Claude Code reads its credentials
  and retains its normal folder-trust prompt; tokenmeter neither answers that prompt nor reads credentials or usage endpoints.
  The next regular collection reads the cache Claude Code writes.
- Do not report the former `general.usagerefresh` problem. A stale model limit is identified by its observed time in the card.

This replaces the automatic `/usage` decision in [ADR 0002](./0002-quota-model-and-data-sources.md) and the related
problem in [ADR 0005](./0005-problems.md). Account-specific folders still follow [ADR 0014](./0014-accounts-and-the-home-of-a-provider.md).

## Consequences

- Model-specific limits stay stale until a person opens Claude's Usage screen. The unscoped bars keep updating from the
  status line without that action.
- Terminal and Claude Code become visible when the person asks for model limits. A newly used account folder may ask for
  trust; tokenmeter does not bypass it.
- The action depends on Claude Code continuing to accept `/usage` as an initial interactive command. A CLI change can break
  the action and must be checked against a real installed version.

## Amendment, 2026-11-10: the background run is back

With Claude Code 2.1.322 `claude -p "/usage" --no-session-persistence --no-chrome` writes the usage copy again. Measured on the
author's Mac: one run moved `fetchedAtMs` from the day before to the minute of the run, and a run with `--debug` logged
`fetchUtilization: GET /api/oauth/usage` and `200` and moved it again. A second run three minutes after the first ended with zero
and left the copy as it was. Read in Claude Code's own program: it writes the copy only when the one it has is a minute old or
more (`Be = 60000`), and when its server does not answer it shows a copy up to an hour old and writes nothing (`Gt = 3600000`).
An unchanged copy after a run is therefore not a failure.

- **Run `/usage` in the background again**, as before 2026-11-08: every 15 minutes and when the person refreshes, never twice
  in a minute, in each Claude account's folder (ADR 0014), only while the Claude quota switch is on. Claude Code reads its own
  credentials; tokenmeter handles none and calls no API.
- **A run says nothing to the person**: refreshed, unchanged, failed, timed out or without `claude`, the card keeps saying when
  the limits were last seen. The former `general.usagerefresh` problem does not come back.
- **Open /usage stays**, for a version of Claude Code whose background run writes nothing, and for an account whose folder
  still asks for trust.
- **A model limit ends with its window** when the window is reported with a later reset (ADR 0002), so a limit the background
  run could not refresh does not stay exhausted after the weekly has renewed.

The background run depends on a behaviour Claude Code has already broken once. If it breaks again, nothing is reported and
the card's last-seen time grows; that, and the button, are the fallback.
