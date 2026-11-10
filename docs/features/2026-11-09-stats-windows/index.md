---
title: Stats, windows as strips
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-09
---

# Stats, windows as strips

The stats show every window of a provider, the 5-hour ones included, as a strip of blocks in time order, and the verdict counts them.

|        |                                    |
| :----- | :--------------------------------- |
| Date   | 2026-11-09                         |
| Status | implemented, 2026-11-09, in 0.11.0 |

## Intent

The stats exist to answer one question: **does the plan fit the way the person uses it, or is it time to move up or down?** Today they
cannot answer it for a plan that has a 5-hour window. The 5-hour windows are not listed, because several of them end in one day and a
row has only a date, and the verdict is drawn from the weekly windows alone. Reaching the ceiling of the 5 hours again and again is the
clearest sign that a plan is tight, and it counts for nothing.

The weekly windows are listed as rows with a date, and the current rows leave no room for the cases that matter: a week the app did not
see is simply absent, and a plan whose weekly figure is not known yet gets a verdict that says nothing about what is missing.

This feature draws both lengths as a strip, with time running left to right, counts the 5 hours in the verdict, which can now say Move up, and says what is
missing when the weekly is unknown. The figure of a block is one point away, in the system's tooltip. The wizard's pages on the stats and
on the suggestion say the same.

## The nucleus

| Part                | Page                      | Status                               |
| :------------------ | :------------------------ | :----------------------------------- |
| Proposal            | [Proposal](./proposal.md) | chosen                               |
| Implementation plan | [Plan](./plan.md)         | built                                |
| Decisions           | none                      | nothing structural, as the plan says |

## Related

- [Usage stats](../2026-11-02-usage-stats/index.md): the view and the verdict this feature changes
- [Bars: left or used](../2026-11-03-bars-display/index.md): the tooltip and the verdict follow the choice
- [Welcome tour](../2026-11-03-welcome-tour/index.md): pages 5 and 6 change
