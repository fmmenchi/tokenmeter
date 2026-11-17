---
title: Loading skeleton
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-16
---

# Loading skeleton

While the data arrives, the panel and the stats draw their cards empty, in the skin's grey, in place of a spinner.

|        |                                    |
| :----- | :--------------------------------- |
| Date   | 2026-11-16                         |
| Status | implemented, 2026-11-16, in 0.14.0 |

## Intent

A spinner says that something is coming, not what. The panel before its first reading and the stats while the history opens or the
logs are read showed a spinner alone. The skeleton draws the shape of what is coming, cards, bars and strips, so the panel does not
jump when it arrives, and it never shows a figure that was not read.

## The nucleus

| Part                | Page                      | Status                               |
| :------------------ | :------------------------ | :----------------------------------- |
| Proposal            | [Proposal](./proposal.md) | chosen: variant C                    |
| Implementation plan | [Plan](./plan.md)         | built                                |
| Decisions           | none                      | nothing structural, as the plan says |

## Related

- [Usage stats](../2026-11-02-usage-stats/index.md): the view whose waits it draws
- [Skins](../2026-11-02-skins/index.md): the skeleton takes the skin's track colour and bar shape
