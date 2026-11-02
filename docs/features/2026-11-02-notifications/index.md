---
title: Notifications
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-02
---

# Notifications

The app tells you with a notification when a window is running out, so you do not have to open the panel to find out.

|        |                         |
| :----- | :---------------------- |
| Date   | 2026-11-02              |
| Status | implemented, 2026-11-02 |

## Intent

The panel says how much is left now, and the pace mark says whether it will last. Both need you to look. A notification says it
when it matters, once for each window and each reset, and says nothing when there is nothing to say.

It is **off by default**: three switches in Settings, each for one kind of notice. It uses what the app already knows, the
remaining quota and the pace, and nothing from the network.

## The nucleus

| Part                | Page                                        | Status   |
| :------------------ | :------------------------------------------ | :------- |
| Proposal            | [Proposal](./proposal.md)                   | chosen   |
| Implementation plan | [Plan](./plan.md)                           | accepted |
| Decisions           | [ADR 0012](../../adr/0012-limit-notices.md) | accepted |

## Related

- [Pace on the bars](../2026-11-01-pace-on-bars/index.md): the pace that "will run out before the reset" reads
- [Burn rate](../2026-10-31-burn-rate/index.md): when a window runs out at its pace
- [Settings switches](../2026-11-01-settings-switches/index.md): the windows a notification counts
