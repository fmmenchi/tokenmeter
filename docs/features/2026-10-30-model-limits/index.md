---
title: Model limits
sidebar_label: Overview
sidebar_position: 1
date: 2026-10-30
---

# Model limits

Some plans have a limit for one model that is part of the weekly limit. tokenmeter shows it as a thin line joined to Weekly's bar.

|        |                                                                 |
| :----- | :-------------------------------------------------------------- |
| Date   | 2026-10-30                                                      |
| Status | implemented, 2026-10-30: built and tested; not yet seen running |

## Intent

The Claude usage page shows a limit for a model (today "Fable"), part of the weekly limit, with its own percentage and its
own reset. It depends on the subscription, so it may not exist. tokenmeter reads it from the usage copy Claude Code keeps in
`~/.claude.json`, which it refreshes by asking Claude Code to run its own `/usage`, so the figure is fresh and tokenmeter
handles no credential. The limit is a window of the provider with a scope, a model's name taken from the data: the code names
no model and no provider, and it appears only when the data has it.

## The nucleus

| Part                | Page                                                          | Status                          |
| :------------------ | :------------------------------------------------------------ | :------------------------------ |
| Proposal            | [Proposal](./proposal.md)                                     | built as chosen: a bracket line |
| Implementation plan | [Implementation plan](./plan.md)                              | done, steps 1 to 6              |
| Decisions           | [ADR 0034](../../adr/0034-limits-can-be-scoped-to-a-model.md) | accepted                        |

## Related

- [Provider cards](../2026-10-30-provider-cards/index.md): the cards that hold the line
- [Enable the Claude Quota](../../use/enable-claude-quota.md): how the Claude figures arrive
