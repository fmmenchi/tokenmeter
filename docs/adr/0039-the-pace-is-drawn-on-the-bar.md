# ADR 0039 — The pace is a value of a window, and only the panel draws it

Status: accepted (2026-11-01); changes the line of [ADR 0038](./0038-a-window-says-when-it-runs-out-at-its-pace.md) that says
"Only the panel draws it", and the way it is drawn

## Context

[ADR 0038](./0038-a-window-says-when-it-runs-out-at-its-pace.md) says when a window runs out with a line of text. A line
takes height where the widget has little, says only the bad news, and has no place in the compact row of a model's limit.
How the answer looks and reads is the feature's, in [its proposal](../features/2026-11-01-pace-on-bars/proposal.md) and in
[Reading the Bars](../use/bars.md). This ADR keeps what is structure.

## Decision

- **The pace is a value, computed in `TokenMeterCore` and drawn by the views.** `WindowUsage.pace(at:)` returns a `Pace`: the
  share of the window still ahead (`aheadFraction`), when the quota runs out (`runsOutAt`), whether the figure is stale
  (`isStale`) and whether it runs out (`runsOut`). The text the interface says is also built in the core
  (`paceFigureText`, `runsOutShortText`), so it is tested without a view.
- **The share ahead is where the bar would end at a steady use.** For a fresh figure it is
  `(resetsAt − observedAt) / length`, and the quota runs out exactly when what is left is under it. For a figure that is
  out of date (older than `WindowUsage.staleAfter`) it is measured **now**, `(resetsAt − now) / length`, because the figure
  can only have gone down since, and it runs out only when the reading is already under it.
- **Nothing is estimated** under the conditions of ADR 0038. A window where nothing was used has a pace and lasts.
- **The panel draws it and the widget does not.** The views take a flag (`showsPace`) and the shared code serves both; the
  widget has no pointer and no room, so it only gets a short phrase from the core, for a fresh figure.
- **The pointer is read by a modifier** (`hovered`) on the shared views; the widget never turns it on.

## Consequences

- No permanent line of text for the pace: a card is as tall as before ADR 0038.
- The look, the words and the states can change without touching this ADR.
- Not verified: the widget on the desktop with the phrase, which is judged on screen and not here.
