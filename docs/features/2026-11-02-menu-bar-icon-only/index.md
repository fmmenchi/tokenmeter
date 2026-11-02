---
title: Menu bar, icon only
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-02
---

# Menu bar, icon only

The menu-bar item is the gauge icon and nothing else, like the other apps in the bar. A dot on the icon says something in
the panel is worth a look.

|        |                         |
| :----- | :---------------------- |
| Date   | 2026-11-02              |
| Status | implemented, 2026-11-02 |

## Intent

Next to the icon the app showed the lowest percentage left across the plans, and a "▲ N" when there were problems. One
percentage across several providers says nothing about any of them, and it does not hold with more providers or
accounts. The count of problems belongs in the panel, where each one has its message and its fix.

The bar keeps one signal: **a dot on the icon**, for anything the panel lists that is worth opening it for. The icon is a
template image, so the dot has the colour of the icon and the menu bar's own, light or dark.

## The nucleus

| Part                | Page                      | Status |
| :------------------ | :------------------------ | :----- |
| Proposal            | [Proposal](./proposal.md) | chosen |
| Implementation plan | [Plan](./plan.md)         | done   |
| Decisions           | none                      |        |

No ADR: it is a choice of what the bar shows, not of structure.

## Related

- [Alerts with a fix](../2026-10-30-alerts-with-a-fix/index.md): the problems the dot stands for
