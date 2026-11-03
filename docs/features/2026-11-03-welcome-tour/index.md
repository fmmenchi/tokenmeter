---
title: Welcome tour
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-03
---

# Welcome tour

The first time the app opens, it points at its own icon in the menu bar and walks the person over the panel in six short stops, then says what it set up on its own.

|        |            |
| :----- | :--------- |
| Date   | 2026-11-03 |
| Status | in design  |

## Intent

tokenmeter has no Dock icon and no window: after the install nothing visible happens except a small gauge in the menu bar, and a person
who does not know where to look may think it did not start. The first thing to teach is where the app lives. The rest of the tour teaches
what the panel shows and what it needs, in the order the person meets it, and the last screen says what the app did by itself on the Mac.

Everything it says comes from what the app really does, and where a sentence is the app's own it is the app's own text.

## The nucleus

| Part                | Page                                       | Status   |
| :------------------ | :----------------------------------------- | :------- |
| Proposal            | [Proposal](./proposal.md)                  | chosen   |
| Implementation plan | [Plan](./plan.md)                          | proposed |
| Decisions           | [ADR 0014](../../adr/0014-welcome-tour.md) | proposed |

## Related

- [Skins](../2026-11-02-skins/index.md) and [Settings in tabs](../2026-11-02-settings-tabs/index.md): the tour ends in Settings and offers a skin
- [Usage stats](../2026-11-02-usage-stats/index.md): the verdict the tour explains
- [Notifications](../2026-11-02-notifications/index.md) and [Updates](../2026-11-02-updater/index.md): what the tour says about the daily check and about notices
