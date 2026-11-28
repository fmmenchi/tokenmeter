---
title: Provider widget, plan
sidebar_label: Plan
sidebar_position: 3
---

# Provider widget, plan

How the [proposal](./proposal.md) is built. The structural decision, a widget configured with an account, is
[ADR 0018](../../adr/0018-a-widget-per-account.md).

## The rules

- **A widget draws one card**, the account chosen with Edit; with none chosen, the first card of the panel. An account that is no
  longer a card (removed or hidden) is said, not replaced.
- **At most two gauges**: the first two windows of the card that are not a model's limit, in the card's order (the windows the
  person chose for it, ADR 0006). Each gauge is its window's label, the figure inside the ring and the reset under it.
- **A model's limit is part of its window** (ADR 0002): a thin inner ring in that window's gauge draws the lowest of them. The small
  widget writes that lowest one under the reset; the medium one lists them all in a column "Weekly by model" beside the gauges.
- **The figure is the panel's**: `figureText(_:at:)`, so Left or Used, "~" for an old or inferred reading and "—" for none read the
  same as on the bars. The ring is filled as far as the bar would be (`BarsDisplay.fraction`), in the colour of what is left (the
  panel's thresholds, or the skin's three colours).
- **An old reading** draws its ring at half strength and the header says its age ("3h ago"); **an exhausted window** writes its
  reset in the notice colour.
- **The skin**: its panel colour behind the widget (as today), its colours on the rings, the track and the text, its typeface. Not
  the shape of its bars: a ring has none.
- **Text at 11 points at least**, the HIG's floor.
- **The welcome wizard** gets a page, "A widget for each account", after the accounts and before Settings: nine pages.
- **What's new** gets an entry for the version that brings it.

## Where each thing goes

| Layer  | Folder                       | What                                                                              |
| :----- | :--------------------------- | :-------------------------------------------------------------------------------- |
| Core   | `Sources/TokenMeterCore/`    | `WidgetGauges`: which card, which gauges, the models of each; the ninth page      |
| Tests  | `Tests/TokenMeterCoreTests/` | `WidgetGaugesTests.swift`, `WelcomeTests.swift`                                   |
| Shared | `Shared/`                    | `GaugeWidgetView`: the small and medium widget, used by the widget and the wizard |
| Widget | `Widget/TokenMeterWidget/`   | the intent, its account entity and query, the configuration                       |
| App    | `App/TokenMeter/Welcome/`    | the ninth page's text and picture                                                 |

## Commits

| #   | Commit                                                   | Files                                                  |
| :-- | :------------------------------------------------------- | :----------------------------------------------------- |
| 1   | `docs(features): provider widget, in design`             | the folder's index, its category, `proposal.md`        |
| 2   | `docs(adr): a widget per account` and the plan           | ADR 0018, `plan.md`, the features table                |
| 3   | `feat(core): the gauges a widget draws`                  | `WidgetGauges.swift`, `WidgetGaugesTests.swift`        |
| 4   | `feat(core): the welcome has a page for the widget`      | `WelcomeState.swift`, `WelcomeTests.swift`             |
| 5   | `feat(core): what's new says the widget`                 | `WhatsNew.swift`                                       |
| 6   | `feat(widget): a gauge widget for one card`              | `GaugeWidgetView.swift`                                |
| 7   | `feat(widget): the widget is configured with an account` | the intent, `TokenMeterWidget.swift`                   |
| 8   | `feat(app): the welcome page of the widget`              | `WelcomePages.swift`                                   |
| 9   | `docs(use): the widget, one per account`                 | the widget's Use page, the welcome page, the changelog |

## Tests

- The first two windows that are not a model's limit become the gauges, in the card's order; a card with one window has one gauge.
- The models of a window go with its gauge, the lowest first named; a model of a window not drawn is left out.
- The chosen card by id; the first card with none; nil for an id that is not a card.
- The wizard has nine pages, the widget's between the accounts and Settings.

## Not verified here

The widget on a desktop, the Edit sheet with the account picker, a widget already placed after the update, the vibrant rendering
of the desktop, and the skins on a real widget: they need the app built and run on a Mac.
