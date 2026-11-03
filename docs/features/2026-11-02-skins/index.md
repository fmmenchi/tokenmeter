---
title: Skins
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-02
---

# Skins

A skin changes how the panel, the widget and the stats look: the colours, the shape of the bars and the typeface. There are five:
System, the look of today, and four taken from well-known editor themes, Dracula, One Dark, Catppuccin and Nord.

|        |                         |
| :----- | :---------------------- |
| Date   | 2026-11-02              |
| Status | implemented, 2026-11-02 |

## Intent

The quota is the one thing the app shows all day, so a person who lives in an editor with a theme they chose may want it to
look at home there. A skin is more than a palette: with only the colours changed, the five looked alike, so each one also
draws the bars its own way and uses its own typeface.

What a bar says does not change: the thresholds, the figures, the tick of the pace and what the warning colour means stay as
they are in every skin.

## The nucleus

| Part                | Page                                | Status   |
| :------------------ | :---------------------------------- | :------- |
| Proposal            | [Proposal](./proposal.md)           | chosen   |
| Implementation plan | [Plan](./plan.md)                   | accepted |
| Decisions           | [ADR 0013](../../adr/0013-skins.md) | accepted |

## Related

- [Seasonal easter eggs](../2026-11-02-seasonal-easter-eggs/index.md): they ride on top of whatever skin is chosen
- [Pace on the bars](../2026-11-01-pace-on-bars/index.md): the tick that every skin keeps
- [Licences](../../use/licenses.md): where the colours come from
