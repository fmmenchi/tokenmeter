---
title: Provider widget
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-28
---

# Provider widget

One widget per provider or account, with at most two gauges: what is left of each window, and when it resets.

|        |            |
| :----- | :--------- |
| Date   | 2026-11-28 |
| Status | building   |

## Intent

Today the widget stacks one card per provider. With two providers the second card does not fit a medium widget and is clipped, and
the small one cuts its lines short: a render of the real views with sample data shows it, and the Design System says so too. A
widget for each provider fits, and lets the person place each one where they want it.

The widget is the simple version of the panel: the quota and the reset, nothing else. Tokens, the moment a window runs out and the
stats stay in the panel.

The feature also updates the welcome wizard, which gets a word on the widget, and the What's new card of the release that brings it.

## The nucleus

| Part                | Page                                               | Status                      |
| :------------------ | :------------------------------------------------- | :-------------------------- |
| Proposal            | [Proposal](./proposal.md)                          | chosen: gauges, at most two |
| Implementation plan | [Plan](./plan.md)                                  | approved, building          |
| Decisions           | [ADR 0018](../../adr/0018-a-widget-per-account.md) | accepted                    |

## Related

- [Accounts](../2026-11-03-accounts/index.md): each account can have a widget of its own
- [Model limits](../2026-10-30-model-limits/index.md): a model's limit is part of Weekly, in the widget as in the panel
- [Skins](../2026-11-02-skins/index.md): the widget follows the skin today; the proposal is drawn in System only
