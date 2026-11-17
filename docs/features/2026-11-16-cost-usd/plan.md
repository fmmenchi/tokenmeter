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

## What the check after 0.15.0 found

- **The list of 0.15.0 was not the providers' page**: it came from a table of 2026-11-03 and priced the cache reads of Fable 5.1 and
  Mythos 5.1 at a tenth of the input ($1) where the page says $0.25. The list is now read from the pages, OpenAI included.
- **Claude Code writes the one-hour cache** (99.6% of its writes on the author's Mac), which costs twice the input, not 1.25 times.
- **Long prompts cost more**: Haiku 5.5 over 100K tokens (71% of its messages on the author's Mac), OpenAI over 272K (7% of
  Codex's). The store now splits the totals by size of prompt.
- **The column squeezed the legend**: drawn from the store of the author's Mac, the names read "O…s" and the tokens wrapped. The figures
  are now written whole, without "≈" on each row, and the name gives way.

## Not verified at the time of writing

- The column in the real panel: it was drawn offscreen from the real store (one month: Claude ≈ $6,085, ChatGPT ≈ $109 for the
  models with a price), in System and Dracula, dark; the "more models" link cannot be drawn offscreen.
- A promotional price (gpt-5.6-sol until 2026-11-30) stays in the list until it is read again.
