---
title: Burn rate, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# Burn rate, proposal

The design that was chosen, [ADR 0038](../../adr/0038-a-window-says-when-it-runs-out-at-its-pace.md) is the decision.

## What changes

| Surface  | What it shows                                                                                                                                                | Why                                            |
| :------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------- |
| Panel    | Under the detail line of a window, one line in the notice colour when the quota would run out before the reset: "at this pace you run out Thursday at 6 pm". | It answers whether the quota lasts.            |
| Widget   | Unchanged.                                                                                                                                                   | The small widget has no room for another line. |
| Settings | Unchanged.                                                                                                                                                   | There is nothing to choose.                    |

## The two variants that were drawn

- **A, always:** a line on every window that can be estimated, "at this pace it lasts until the reset" when it does.
- **B, only when it runs out first**, the one chosen: the line is the bad news only, so a card with nothing to warn about is
  the card as it was and a line that appears means something.

The cost of B is that no line is ambiguous: it can mean the quota lasts, or that nothing can be estimated.

## Rules

- **Only a fresh, reported figure is estimated**, with a reset time and at least 10% of the window gone.
- **The time is rounded to the hour**: today, tomorrow or the weekday, then "6 pm".
- **No provider, plan or window is named**: ChatGPT's windows are estimated the same way.
- **The pace is an average since the last reset**, so a quiet night counts as slow use.
