---
title: Alerts with a fix
sidebar_label: Overview
sidebar_position: 1
date: 2026-10-30
---

# Alerts with a fix

The app tells you what is wrong, for each AI tool it reads or for itself, and, when it can, fixes it from the menu-bar
panel.

|        |                                                                              |
| :----- | :--------------------------------------------------------------------------- |
| Date   | 2026-10-30                                                                   |
| Status | implemented, 2026-10-30: built and tested, not yet checked running on screen |

## Intent

Before this, one message, a string in the snapshot, says that projects override the Claude status line. Other messages are
scattered across the panel and Settings. A problem gets one shape (in the code a _problem_, to the user an _alert_): a topic (a provider or `general`), a message, an
optional fix and a way to read more, shown the same way on the menu bar, the widget and the panel. Each provider can have
problems and solutions of its own, and the common code never names a provider.

## The nucleus

| Part                | Page                                   | Status                                      |
| :------------------ | :------------------------------------- | :------------------------------------------ |
| Proposal            | [Proposal](./proposal.md)              | built as chosen; changes listed in the page |
| Implementation plan | [Implementation plan](./plan.md)       | done, steps 1 to 10                         |
| Decisions           | [ADR 0005](../../adr/0005-problems.md) | accepted                                    |

## Related

- [Reading the Bars](../../use/bars.md): the states a problem sits beside
- [Enable the Claude Quota](../../use/enable-claude-quota.md): the first problem's subject
