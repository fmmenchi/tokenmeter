---
title: Hide a provider
sidebar_label: Overview
sidebar_position: 1
date: 2026-10-30
---

# Hide a provider

An eye button in Settings takes a provider's card off the panel and the widget, and puts it back.

|        |                                 |
| :----- | :------------------------------ |
| Date   | 2026-10-30                      |
| Status | in design: nothing is built yet |

## Intent

A tool you use but do not want to watch still has a card, and in the medium widget it takes the place of one you do. Each
row of the provider list in Settings gets an eye button. A hidden provider has no card, is not in the menu-bar percentage
and keeps its place in the order and its choice of windows, so showing it again puts it back as it was. It applies to
every provider in `providers.json`.

## The nucleus

| Part                | Page                                                   | Status                 |
| :------------------ | :----------------------------------------------------- | :--------------------- |
| Proposal            | [Proposal](./proposal.md)                              | chosen: the eye button |
| Implementation plan | [Implementation plan](./plan.md)                       | proposed               |
| Decisions           | [ADR 0036](../../adr/0036-a-provider-can-be-hidden.md) | accepted               |

## Related

- [Provider cards](../2026-10-30-provider-cards/index.md): the cards, their order and their windows, which this extends
