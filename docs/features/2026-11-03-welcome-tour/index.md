---
title: Welcome tour
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-03
---

# Welcome tour

The first time the app opens, a small window walks the person through six pages: where the app lives, what the bars and the tick say, what the
buttons and the stats do, and where Settings is.

|        |            |
| :----- | :--------- |
| Date   | 2026-11-03 |
| Status | in build   |

## Intent

tokenmeter has no Dock icon and no window: after the install nothing visible happens except a small gauge in the menu bar, and a person who
does not know where to look may think it did not start. The tour says where the app lives, then explains the panel in the order the person meets
it. It is a classic wizard in a window of its own, with a picture of the real panel on each page, so it stands apart from the rest of the app.

Everything it says comes from what the app really does, and where a sentence is the app's own it is the app's own text.

## The nucleus

| Part                | Page                      | Status   |
| :------------------ | :------------------------ | :------- |
| Proposal            | [Proposal](./proposal.md) | chosen   |
| Implementation plan | [Plan](./plan.md)         | proposed |

No ADR: nothing here moves a boundary.

## Related

- [Skins](../2026-11-02-skins/index.md) and [Settings in tabs](../2026-11-02-settings-tabs/index.md): the last page is about Settings
- [Usage stats](../2026-11-02-usage-stats/index.md): the verdict the tour explains
- [Updates](../2026-11-02-updater/index.md): what the tour says about the daily check
