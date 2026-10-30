# ADR 0035 — Provider cards: order and visible windows are preferences

Status: proposed (2026-10-30); narrows [ADR 0018](./0018-the-config-file-is-the-only-source.md) for the order in which providers are shown

## Context

Every provider is a block of its windows, in the order of `providers.json` ([ADR 0018](./0018-the-config-file-is-the-only-source.md)).
The medium widget holds one provider fully and clips the next, so the order decides what a person sees, and nobody can
hide a window they do not watch. The design chosen in [the proposal](../features/2026-10-30-provider-cards/proposal.md)
makes each provider a card, with a choice of windows and an order set in Settings.

## Decision

- **The order and the visible windows are preferences of the app, not part of `providers.json`.** They live in the app's
  defaults, keyed by provider id: the file is the user's and the app does not rewrite it
  ([ADR 0033](./0033-add-the-claude-integration-to-an-existing-providers-file.md)).
- **What is read does not change.** Collection, the snapshot's windows and the problems still follow the file. Only what is
  **shown** follows the preferences: the order of the cards, and which windows of a provider have a row. The file's order is
  the default, and a provider with no preference is last.
- **The app applies them when it writes the snapshot**, so the widget keeps drawing what it is given and computes nothing
  ([ADR 0001](./0001-stack-swiftui-widgetkit.md)). Settings reads the unfiltered list of providers and windows from the
  app, not from the snapshot.
- **The choice is a set of windows by name**, taken from the windows the provider declares, never from a fixed list. The
  interface offers each window and "Both" (all); no provider and no window is named in the common code. At least one
  window always stays visible.
- **A hidden window is out of every figure shown.** The menu-bar percentage is the lowest of the visible windows, and a
  hidden one raises no problem.
- **The card uses system colours only** (`Color.primary` at 4% for its fill, the text styles and the existing tints), so
  the light and the dark appearance both hold without a value written for either.

## Consequences

- The widget's order follows the person, which is the practical reason to reorder: the medium widget shows the first card.
- A preference for a provider that leaves `providers.json` stays in the defaults and does nothing; no cleanup is needed.
- The design system defines only the light appearance; it gains a dark theme with the close of this feature, with the
  macOS system dark values marked assumed.
- Not verified: dragging in a `List` of an app that lives in the menu bar; the widget in the dark appearance on the
  desktop.
