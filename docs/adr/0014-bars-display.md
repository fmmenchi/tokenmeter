# ADR 0014 — Bars display: left or used is a choice of the app, it reaches the widget in the snapshot, and the colour keeps following what is left

Status: proposed (2026-11-03, with the [plan](../features/2026-11-03-bars-display/plan.md)); accepted when Fabio says so

## Context

[ADR 0002](./0002-quota-model-and-data-sources.md) makes the remaining quota the number that matters, and every view draws it:
`25% left`, a bar filled to the remaining fraction, and a mark where a steady use would put the bar. A person can read the same
quota the other way (`75% used`) and asked for it ([proposal](../features/2026-11-03-bars-display/proposal.md)). Three things are
structural: where the choice lives, how the widget, which is another process, learns it, and what stays tied to what is left.

## Decision

- **The choice is a value in `TokenMeterCore`**: an enum of two cases, `left` and `used`, with the one rule that is not a view's
  business: the fraction a bar is filled to, and the position of the pace mark, for each case. Left is the default and draws what the
  views always drew. The data does not change: the collectors, the snapshot's windows and the run-out maths keep reading and storing
  the remaining fraction.
- **The choice travels in the snapshot**, as the skin does ([ADR 0013](./0013-skins.md)). `Snapshot` gains `barsDisplay`, written by
  the app when it publishes; the widget reads it with the usage it draws. A snapshot from before it, or with a value this version does
  not know, is `left`. Choosing publishes again and reloads the widget.
- **The choice itself is kept in the app's defaults** and read by `Meter`, like the other choices of Settings.
- **The views read it from the environment**, one value set once at the root of the panel and of the widget, next to the skin. A view
  that does not find one draws as before.
- **What stays tied to what is left**: the colour of a bar and the thresholds of the notices (40% and 15% left, [ADR 0012](./0012-limit-notices.md)),
  the run-out phrases, the stats and the suggestion. They are about the quota, not about how a bar reads.

## Consequences

- The default changes nothing for anyone, and an old snapshot or a widget that is not updated yet draws as it did.
- A bar at `75% used` is orange and one at `95% used` is red: the colour says what is left in both readings. A person who reads
  `used` and expects red to mean "a lot used" gets that for the high values.
- Two places draw a bar's figure and fill, `WindowRow` and `ScopedWindowRow`; both change, and a third place that draws one has to read
  the same value.
- The quota text elsewhere (notifications, stats) keeps saying `left`, so the app says both words in different places. That is
  deliberate for now and is the first thing to revisit if it is missed.
