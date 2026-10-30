---
title: Provider cards
sidebar_label: Overview
sidebar_position: 1
date: 2026-10-30
---

# Provider cards

Each provider is a card, you choose which of its windows to see, and you put the cards in the order you want.

|        |                                 |
| :----- | :------------------------------ |
| Date   | 2026-10-30                      |
| Status | in design: nothing is built yet |

## Intent

Today a provider is a block with all of its windows, in the order of `providers.json`. The medium widget holds one
provider fully and clips the rest, so the order decides what you see, and nobody asked for the 5 hours of a tool they
only watch weekly. A provider becomes a card, drawn the same in the panel and the widget, with a choice of windows
(5 hours, Weekly or Both) and a position you set in Settings. It applies to every provider in `providers.json`, and the
code names none of them. The light and the dark appearance both hold, because the card uses only system colours.

## The nucleus

| Part                | Page                                                                           | Status               |
| :------------------ | :----------------------------------------------------------------------------- | :------------------- |
| Proposal            | [Proposal](./proposal.md)                                                      | chosen: filled cards |
| Implementation plan | [Implementation plan](./plan.md)                                               | proposed             |
| Decisions           | [ADR 0035](../../adr/0035-provider-cards-order-and-windows-are-preferences.md) | proposed             |

## Related

- [Reading the Bars](../../use/bars.md): the window rows a card holds
- [Alerts with a fix](../2026-10-30-alerts-with-a-fix/index.md): the banners above the cards
