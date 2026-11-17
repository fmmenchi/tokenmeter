---
title: Cost in USD
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-16
---

# Cost in USD

The stats write what the counted tokens would cost at API list prices: by model, for the range, and on a closed card's line.

|        |                                    |
| :----- | :--------------------------------- |
| Date   | 2026-11-16                         |
| Status | implemented, 2026-11-16, in 0.15.0 |

## Intent

The stats count tokens, a number that means little on its own. The other local tools turn it into dollars; here it says what the same
use would cost billed by the token, an estimate set beside the plan, never what is paid.

## The nucleus

| Part                | Page                                                  | Status            |
| :------------------ | :---------------------------------------------------- | :---------------- |
| Proposal            | [Proposal](./proposal.md)                             | chosen: variant A |
| Implementation plan | [Plan](./plan.md)                                     | built             |
| Decisions           | [ADR 0016](../../adr/0016-cost-at-api-list-prices.md) | accepted          |

## Related

- [Usage stats](../2026-11-02-usage-stats/index.md): the tokens by model the cost is drawn from
