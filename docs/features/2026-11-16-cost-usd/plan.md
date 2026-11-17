---
title: Cost in USD, plan
sidebar_label: Plan
sidebar_position: 3
---

# Cost in USD, plan

How the [proposal](./proposal.md) is built, under [ADR 0016](../../adr/0016-cost-at-api-list-prices.md).

## Where each thing goes

| Layer | Folder                       | What                                                                                                      |
| :---- | :--------------------------- | :-------------------------------------------------------------------------------------------------------- |
| Core  | `Sources/TokenMeterCore/`    | `Pricing` (the dated list, the cost of a model), the caches in `ModelTotal`, the cost in `ModelBreakdown` |
| Tests | `Tests/TokenMeterCoreTests/` | `PricingTests.swift`                                                                                      |
| App   | `App/TokenMeter/`            | `StatsView.swift`: the column, the total, the closed card's line                                          |
| Docs  | `docs/`                      | ADR 0016, the stats page                                                                                  |

## The steps

| Step | Commit                                                                                 | Files                                                   |
| :--- | :------------------------------------------------------------------------------------- | :------------------------------------------------------ |
| 1    | `feat(core): the cost of the counted tokens at api list prices, by model and in all`   | `Pricing.swift`, `UsageStore.swift`, `UsageStats.swift` |
| 2    | `test(core): the price list, the cost with the caches and a family without a price`    | `PricingTests.swift`                                    |
| 3    | `feat(app): the stats show the cost of each model and of the range at api list prices` | `StatsView.swift`                                       |
| 4    | `docs`: ADR 0016 and the stats page                                                    | `adr/0016-…`, `use/stats.md`                            |
| 5    | `docs(features)`: this folder and its row                                              | this folder, `features/index.md`                        |

## Tests

Opus 5.5 is not read as Opus 5; a log suffix is ignored; a model not listed has no price; input, output and both caches are counted;
a cache read not listed is a tenth of the input; a family with an unpriced model has no cost and the total says it is partial.

## Not verified at the time of writing

- The column and the total on screen, with real data and in the five skins.
- The prices themselves against the provider's page on the day of the release: they come from a table dated 2026-11-03.
- The cost of ChatGPT: its models have no price in the list.
