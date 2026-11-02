---
title: Usage stats
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-02
---

# Usage stats

The panel gets a second view, behind an icon, that says how your use is going over time: how much quota was left at
the end of each window, whether you hit the ceiling, and which models took the tokens.

|        |                         |
| :----- | :---------------------- |
| Date   | 2026-11-02              |
| Status | implemented, 2026-11-02 |

## Intent

Today the panel says how much is left **now**. It does not say whether the plan is the right one, because nothing is
kept: the app holds the last reading and the logs that Claude Code and Codex happen to still have. Claude Code deletes
its old logs, and Claude's quota percentage is nowhere in them, so the past cannot be rebuilt after the fact.

This feature keeps what the app sees, as facts, each with its source and its time, in a small local database, and
draws statistics from those facts only. **A past that cannot be measured is left empty, never estimated.** The first
version shows, for each provider, the quota left at the end of each window, whether the ceiling was hit, and the first
three models by tokens. A verdict (stay, move down) and a chip in the widget come in a later version.

## The nucleus

| Part                | Page                                          | Status   |
| :------------------ | :-------------------------------------------- | :------- |
| Proposal            | [Proposal](./proposal.md)                     | chosen   |
| Implementation plan | [Plan](./plan.md)                             | done     |
| Decisions           | [ADR 0010](../../adr/0010-the-usage-store.md) | accepted |

## Related

- [Pace on the bars](../2026-11-01-pace-on-bars/index.md): what the panel says about the present
- [Burn rate](../2026-10-31-burn-rate/index.md): when a window runs out at its pace
- [Provider cards](../2026-10-30-provider-cards/index.md): one card for each provider
- [Data sources](../../develop/data-sources.md): where the numbers come from today
