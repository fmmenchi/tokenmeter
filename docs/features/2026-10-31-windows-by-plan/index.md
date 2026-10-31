---
title: Windows by plan
sidebar_label: Overview
sidebar_position: 1
date: 2026-10-31
---

# Windows by plan

A card shows only the windows the plan has. A window the plan no longer has, like the 5 hours of Ultra, is not drawn.

|        |                                                                 |
| :----- | :-------------------------------------------------------------- |
| Date   | 2026-10-31                                                      |
| Status | implemented, 2026-10-31: built and tested; not yet seen running |

## Intent

Anthropic removed the 5-hour limit from its Ultra plan (formerly Max 20x). The app kept drawing a grey "5 hours: unknown"
row for it. The windows a card shows now come from the data, as a model's limit already does: when fresh data lists the other
limits and not this one, the plan does not have it. When nothing is known the row stays, because unknown is not absent. No
plan is named in the code, so a plan that gains or loses a window needs no release.

## The nucleus

| Part                | Page                                                                    | Status             |
| :------------------ | :---------------------------------------------------------------------- | :----------------- |
| Proposal            | [Proposal](./proposal.md)                                               | built as chosen    |
| Implementation plan | [Implementation plan](./plan.md)                                        | done, steps 1 to 5 |
| Decisions           | [ADR 0037](../../adr/0037-a-window-exists-only-if-the-data-lists-it.md) | accepted           |

## Related

- [Model limits](../2026-10-30-model-limits/index.md): the same idea for a model's limit
- [Provider cards](../2026-10-30-provider-cards/index.md): the cards and their windows
