---
title: Problems
sidebar_label: Overview
sidebar_position: 1
---

# Problems

The app tells you what is wrong, for each AI tool it reads or for itself, and, when it can, fixes it from the menu-bar
panel. Status: **proposed**, nothing is built yet.

## Intent

Today one message, a string in the snapshot, says that projects override the Claude status line. Other messages are
scattered across the panel and Settings. A problem gets one shape: a topic (a provider or `general`), a message, an
optional fix and a way to read more, shown the same way on the menu bar, the widget and the panel. Each provider can have
problems and solutions of its own, and the common code never names a provider.

## The nucleus

| Part                | Page                                                                                                                                                                                                                                        | Status                    |
| :------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | :------------------------ |
| Proposal            | [Problems: proposal](./proposal.md)                                                                                                                                                                                                         | chosen, three points open |
| Implementation plan | [Problems: implementation plan](./plan.md)                                                                                                                                                                                                  | proposed                  |
| Decisions           | [ADR 0030](../../adr/0030-problems-with-a-topic-and-a-fix.md), [ADR 0031](../../adr/0031-problems-come-from-the-app-and-from-provider-integrations.md), [ADR 0032](../../adr/0032-a-features-section-groups-proposal-plan-and-decisions.md) | proposed                  |

## Related

- [Reading the Bars](../../use/bars.md): the states a problem sits beside
- [Enable the Claude Quota](../../use/enable-claude-quota.md): the first problem's subject
