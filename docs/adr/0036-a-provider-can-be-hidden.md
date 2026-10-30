# ADR 0036 — A provider can be hidden

Status: accepted (2026-10-30); extends [ADR 0035](./0035-provider-cards-order-and-windows-are-preferences.md)

## Context

[ADR 0035](./0035-provider-cards-order-and-windows-are-preferences.md) lets a person order the provider cards and choose
their windows. Nothing lets them take a provider off altogether: a tool they use but do not want to watch still has a card,
and in the medium widget it takes the place of one they do.

## Decision

A provider can be **hidden** from Settings, with an eye button on its row ([the proposal](../features/2026-10-30-provider-visibility/proposal.md)).

- **It is a preference of the app**, kept per provider id in the app's defaults, like the order. `providers.json` is not
  written.
- **A hidden provider has no card** in the panel or the widget, and it is not in the menu-bar percentage. Its row stays in
  Settings, dimmed, so it can be shown again. It **keeps its place in the order and its choice of windows**.
- **Reading does not change**: the data is collected for every provider and the snapshot carries all of them. The app
  leaves the hidden ones out when it applies the preferences, as it does for the order and the windows.
- **One provider always stays.** The eye of the last shown provider is disabled, and if every provider were hidden the
  first in the order is shown.
- **A hidden provider's problems still show** in the panel, as banners: they concern the person, not the card. Only the
  chip has nowhere to sit.
- **A provider added later is shown.**

## Consequences

- The preferences gain `hidden`, and `Snapshot.applying` leaves hidden providers out.
- The medium widget shows the first shown provider fully, so hiding one is a way to choose what it clips.
- Not verified: how the eye button reads next to the arrows on screen, in the light and the dark appearance.
