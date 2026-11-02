---
title: Updates
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-02
---

# Updates

The app knows when a new version is out, tells you, and installs it: it quits, replaces itself and the widget it carries,
opens again and runs its migrations. Your history is kept, not read again from nothing.

|        |                         |
| :----- | :---------------------- |
| Date   | 2026-11-02              |
| Status | implemented, 2026-11-02 |

## Intent

Today whoever has v0.1.0 has no way to learn that v0.2.0 exists: the app does not look, and the widget is inside the app, so
it only changes when the app does. An updater closes both gaps with one mechanism.

It is on by default: checking for updates is what people expect of a Mac app, and an update you do not know about is a bug
you keep. It can be turned off in Settings. It contacts one address, once a day, and sends nothing about you or your use.

## The nucleus

| Part                | Page                                  | Status   |
| :------------------ | :------------------------------------ | :------- |
| Proposal            | [Proposal](./proposal.md)             | chosen   |
| Implementation plan | [Plan](./plan.md)                     | done     |
| Decisions           | [ADR 0011](../../adr/0011-updates.md) | accepted |

## Related

- [Menu bar: icon only](../2026-11-02-menu-bar-icon-only/index.md): the dot on the icon that this feature also uses
- [Usage stats](../2026-11-02-usage-stats/index.md): the store that an update must not read again from nothing
