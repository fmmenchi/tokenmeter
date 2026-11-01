---
title: Settings switches
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-01
---

# Settings switches

In Settings a provider has a switch that is the only thing that hides it, and each window under it has a switch of its own.

|        |                                                          |
| :----- | :------------------------------------------------------- |
| Date   | 2026-11-01                                               |
| Status | in design, 2026-11-01: the design is approved, plan next |

## Intent

Today a provider can be hidden in two ways: with the eye, or by turning off its last window, and a hidden provider shows
every window off, so the choice made before is not visible. Showing it again selects every window. Two controls for one
state is what made it unclear what a click does.

This feature gives the provider one **switch**, in place of the eye, as the only way to hide it, and one switch for each
window under it, in a vertical list, with a model's limit indented under its window. The last window cannot be turned
off. A provider that is off keeps its list, dimmed, and the choice is kept for when it is turned on.

## The nucleus

| Part                | Page                      | Status |
| :------------------ | :------------------------ | :----- |
| Proposal            | [Proposal](./proposal.md) | chosen |
| Implementation plan | not written               | next   |
| Decisions           | not written               | next   |

## Related

- [Hide a provider](../2026-10-30-provider-visibility/index.md): the eye this feature replaces
- [Provider cards](../2026-10-30-provider-cards/index.md): the order and the choice of windows in Settings
- [Model limits](../2026-10-30-model-limits/index.md): the limit that sits under Weekly
