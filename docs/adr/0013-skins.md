# ADR 0013 — Skins: a skin is data in the core, it reaches the widget in the snapshot, and the views read it from the environment

Status: accepted (2026-11-02, with the plan of the [skins](../features/2026-11-02-skins/plan.md); Fabio asked to carry the feature to
the end and to release it)

## Context

A skin changes the colours of the panel, the card and the bar, the quota colours, the shape of the bar and the typeface
([proposal](../features/2026-11-02-skins/proposal.md)). Three things are structural: where the definition of a skin lives, how the
widget, which is another process, learns which skin was chosen, and how the shared views take their look from it without each
view asking. Today the views use only system colours and their opacities ([ADR 0006](./0006-display-preferences.md)), the
widget reads the snapshot the app publishes and nothing else
([ADR 0001](./0001-app-architecture.md)), and the colour of a bar is decided in one place, `WindowUsage.tint`.

## Decision

- **A skin is a value in `TokenMeterCore`**: an enum with, for each of the dark and the light appearance, a palette of plain
  numbers (the panel, the card, the track, the text, the secondary text, the accent, the three colours of a quota and the tick),
  the shape of the bar, the typeface and the roundness of a card. The core uses no framework, so the tests can say that a palette is
  what the licence page says it is and that the text can be read on the card. System is the skin that has no palette: it means
  "draw as the views always did".
- **The choice travels in the snapshot.** `Snapshot` gains an optional `skin`, written by the app when it publishes, as the
  problems already are. The widget reads it with the usage it draws, so no second channel and no second file exist, and an old
  snapshot without it is System. Choosing a skin publishes again and reloads the widget.
- **The choice itself is kept in the app's defaults**, like the other choices of Settings, and read by `Meter`.
- **The views read a style from the environment.** One modifier, `skinned(_:)`, turns a skin and the appearance into a style that
  it puts in the environment, sets the typeface and the text colour, and the shared views (the bar, the card, the tick, the quota
  colours) take what they need from it. A view that does not find one draws as before. The panel and the widget apply the modifier
  once, at the root; Settings does not.
- **Nothing leaves the Mac** and nothing is asked: a skin is data inside the app.

What a skin looks like, which five exist and what each colour is are the feature's, in its
[proposal](../features/2026-11-02-skins/proposal.md), and change without an ADR.

## Consequences

- A skin is tested in the core, which the gate builds; the drawing of the five bars is in the shared views, which only
  `xcodebuild` builds, so it is checked by drawing the real views offscreen and by looking at the app.
- The panel and the widget stop using the window's translucent material when a skin other than System is chosen.
- The widget learns the skin only when the app publishes, so it can be one refresh late after a change.
- Dark-only themes do not exist here: every skin has both appearances. Where a theme has no official light version the light
  colours are derived and the licence page says so. A quota colour that is under 3 : 1 against what its bar is drawn on is
  derived too (2026-11-03), and a test keeps every palette above that line.
- The colours come from themes under the MIT licence, and their notices are kept in the repository and in the
  [licences page](../use/licenses.md).
- Not verified: how the widget draws a solid container background in every family and appearance, and the real panel with a
  solid colour over the window's own material.
