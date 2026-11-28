# ADR 0018 — A widget per account, chosen by the person

Status: accepted (2026-11-28)

## Context

The widget draws every card of the panel, one under the other ([ADR 0001](./0001-app-architecture.md)). With two cards the second
does not fit a medium widget and is clipped, and the small one cuts its lines short: a render of the real views with sample data
shows it, and the Design System says so. Since [ADR 0014](./0014-accounts-and-the-home-of-a-provider.md) a person can have several
accounts, so the cards only grow. The [proposal](../features/2026-11-28-provider-widget/proposal.md) gives each card a widget of its
own, with at most two gauges.

## Decision

- **One widget kind, configured with an account.** The widget becomes an `AppIntentConfiguration` (WidgetKit, macOS 14, the
  deployment target): its intent has one parameter, the account, and the person picks it with Edit on the widget. The kind keeps
  its name, `TokenMeterWidget`, so the widgets already on a desktop stay there; with no account chosen a widget shows the first
  card of the panel.
- **The accounts the intent offers are the cards of the snapshot** the widget already reads from the App Group: the panel's cards,
  in its order, a hidden card left out ([ADR 0006](./0006-display-preferences.md)). An account is named by its card's id and title.
  Nothing new is written for the widget and nothing else is read.
- **A widget whose account is no longer a card** (removed or hidden) says so and asks to choose another; it does not fall back to
  another account silently.
- **What a widget draws is decided in the core**: at most two gauges, the first two windows of the card that are not a model's
  limit, in the card's order; the limits of models of a window go with that window's gauge. The views only draw it.
- **No provider mark or colour of its own.** The snapshot does not say which tool an account is of, so a widget is named by its
  card's title, as the panel and the menu bar name it. The marks and tints of the proposal are left out.

## Consequences

- A widget shows one card. A person with two accounts adds two widgets; one already on the desktop shows the first card after the
  update, instead of all of them.
- The widget extension links AppIntents, a system framework: no dependency is added.
- The intent's query runs in the widget extension and reads the same snapshot as the widget, so the list follows the panel without
  the app being asked.
- Not verified until it runs on a Mac: the account picker in the widget's Edit sheet, a widget already placed keeping its place
  after the update, and the vibrant rendering of the desktop, which desaturates the gauges' colours (the figure stays written).
