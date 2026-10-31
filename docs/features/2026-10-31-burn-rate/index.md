---
title: Burn rate
sidebar_label: Overview
sidebar_position: 1
date: 2026-10-31
---

# Burn rate

A window says when its quota would run out at the pace it has had, when that is before the reset.

|        |                                                                   |
| :----- | :---------------------------------------------------------------- |
| Date   | 2026-10-31                                                        |
| Status | implemented, 2026-10-31: built and tested; not yet seen on screen |

## Intent

A bar says how much is left, not whether it lasts until the reset. The panel now adds a line under a window when, at the
pace since its last reset, the quota would run out before it: "at this pace you run out Thursday at 6 pm". When it lasts,
nothing is said. Without a fresh figure, or too early in the window, nothing can be estimated and nothing is said.

## The nucleus

| Part                | Page                                                                     | Status             |
| :------------------ | :----------------------------------------------------------------------- | :----------------- |
| Proposal            | [Proposal](./proposal.md)                                                | built as chosen    |
| Implementation plan | [Implementation plan](./plan.md)                                         | done, steps 1 to 4 |
| Decisions           | [ADR 0038](../../adr/0038-a-window-says-when-it-runs-out-at-its-pace.md) | accepted           |

## Related

- [Windows by plan](../2026-10-31-windows-by-plan/index.md): the windows a card has
- [Provider cards](../2026-10-30-provider-cards/index.md): the cards that carry the line
