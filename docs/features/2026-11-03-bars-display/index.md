---
title: Bars, left or used
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-03
---

# Bars, left or used

A choice in Settings says whether the bars show how much is left (`25% left`, the default) or how much is used (`75% used`).

|        |                       |
| :----- | :-------------------- |
| Date   | 2026-11-03            |
| Status | in design, 2026-11-03 |

## Intent

The bars have always said what is left, because that is the number that matters when a limit is near. Someone who comes from another
monitor, or who simply thinks of a plan as something that fills up, reads `99% left` as a lot of arithmetic. They asked for the other
reading: `1% used`. It is one global choice, kept in the app, and it changes only how the same quota is shown.

The wizard changes with it: its page on the bars says the figure is what is left and where to change it, and its page on Settings names
the choice.

## The nucleus

| Part                | Page                                       | Status           |
| :------------------ | :----------------------------------------- | :--------------- |
| Proposal            | [Proposal](./proposal.md)                  | variant A chosen |
| Implementation plan | [Plan](./plan.md)                          | proposed         |
| Decisions           | [ADR 0014](../../adr/0014-bars-display.md) | proposed         |

## Related

- [Skins](../2026-11-02-skins/index.md): the other choice that travels from the app to the widget in the snapshot
- [Welcome tour](../2026-11-03-welcome-tour/index.md): pages 2 and 7 change
- [Settings in tabs](../2026-11-02-settings-tabs/index.md): the choice lives in General
