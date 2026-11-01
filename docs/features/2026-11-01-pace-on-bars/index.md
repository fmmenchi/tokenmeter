---
title: Pace on the bars
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-01
---

# Pace on the bars

A mark on the bar says whether the quota lasts until the reset, a hover says when it runs out, and an `i` explains both.

|        |                                                        |
| :----- | :----------------------------------------------------- |
| Date   | 2026-11-01                                             |
| Status | in design, 2026-11-01: ADR proposed, nothing built yet |

## Intent

[Burn rate](../2026-10-31-burn-rate/index.md) added a line under a window that would run out before its reset. The line
takes a row of height, says only the bad news, and has no place in the compact row of a model's limit or in the widget.
This feature moves the answer onto the bar: a **mark** where the bar would end at a steady use, a **hover** on the bar with
the date, an **`i`** by the provider's name that explains the mark, and, in the widget, the date in short inside the detail
line. The permanent line of the panel goes.

## The nucleus

| Part                | Page                                                       | Status   |
| :------------------ | :--------------------------------------------------------- | :------- |
| Proposal            | [Proposal](./proposal.md)                                  | chosen   |
| Implementation plan | [Implementation plan](./plan.md)                           | written  |
| Decisions           | [ADR 0039](../../adr/0039-the-pace-is-drawn-on-the-bar.md) | proposed |

## Related

- [Burn rate](../2026-10-31-burn-rate/index.md): the line this feature replaces
- [Model limits](../2026-10-30-model-limits/index.md): the thin bar that gets the mark
