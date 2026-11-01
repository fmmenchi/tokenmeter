# ADR 0039 — The pace is drawn on the bar

Status: accepted (2026-11-01); changes the line of [ADR 0038](./0038-a-window-says-when-it-runs-out-at-its-pace.md) that says
"Only the panel draws it", and how the panel draws it

## Context

ADR 0038 says when a window runs out with a line of text under it, in the panel only. Looking at it, three things came up:

- **The line takes a row of height where height is short.** From the CSS of the Views, the medium widget (338 × 158) holds
  little more than its first card: the two cards are about 300 px tall. This is computed from the drawing, not seen on the
  real widget.
- **A line says only the bad news.** No line can mean the quota lasts or that nothing can be estimated.
- **A model's limit has the figure computed but nothing to draw it in**: its compact row has no room for a sentence.

## Decision

**The pace is a mark on the bar, the date is in a hover on the bar, and an `i` explains both**
([the proposal](../features/2026-11-01-pace-on-bars/proposal.md)).

- **A mark on the bar** of every window whose pace can be estimated. It sits at the share of the window still ahead,
  `(resetsAt − observedAt) / length`, with `observedAt` as in `RunOut.swift`: where the bar would end if the window were
  used steadily. The bar ending before the mark means the quota runs out before the reset, and ending after it means it
  lasts, exactly: the quota runs out first when what is left is less than the share of the window still ahead. The mark is in the notice colour when it
  runs out and in the primary text colour when it lasts. Nothing is estimated under the conditions of ADR 0038, and then
  there is no mark: a mark with the bar to its right says it lasts, and no mark says nothing can be said. One condition of
  ADR 0038 does not carry over: a window where nothing was used has a mark, since it lasts, and its hover says so.
- **A figure that is out of date has a mark too** (changed 2026-11-01, after it was seen on screen). Codex writes its quota
  only when it runs, so ChatGPT's figure is older than ten minutes most of the time and, under ADR 0038, had no mark. The
  mark is then drawn at half strength, at the share of the window still ahead **now**, `(resetsAt − now) / length`, so it
  moves left as time passes, and the bar is the last reading, which can only have gone down since. It is orange only when
  the bar is already before the mark, since then the quota runs out even if nothing was used since; otherwise it is in the
  text colour. No moment is given for it. The conditions of ADR 0038 for a reported window with a reset time ahead and at
  least a tenth of the window gone still apply.
- **The date is in the figure on the bar's label line**, for the time the pointer is on the bar (changed 2026-11-01, after the
  system tooltip and then a bubble of ours were seen on screen). The figure, "20% left", becomes "out Thu 6 pm", in the
  notice colour, where the quota runs out. Where it lasts it says "lasts until reset". For a figure that is out of date it
  says "seen 22 min ago", or, in the notice colour, "runs out anyway" when the bar is already before the mark.
  Nothing else moves: the label does not, the other rows do not, nothing is covered and no layer is drawn. A bubble covered
  the row above, and a swap of the detail line read as a layout shift. The system tooltip did not show at all: the app has
  no Dock icon and its panel opens without making the app active. The permanent line of ADR 0038 goes, so a card is as tall
  as it was before that ADR.
- **A model's thin bar** has the same mark, 8 px tall, and the same swap on its own figure at the end of its row, whose
  column is wide enough for the longest text so that the bar does not change length. It has no line of its own. The
  provider gives it a reset time of its own.
- **An `i` beside the provider's name** opens a popover on a click. It closes with its `x`, with a second click on the `i` or
  with a click outside. It says: "The mark is how much you'd have left if you used it steadily until the reset. A bar
  shorter than the mark means you are going too fast. Hover the bar to see when." and ends with a "Learn more" link to a
  section of the Bars page of the docs, built from the same base as the problems' Learn more.
- **The widget has no mark and no hover**, since it has no pointer. Where a window would run out, its detail line says it
  in short, in the notice colour and semibold: "3.4B tokens · out Thu 6 pm · resets in 3d 14h". It is the window's, not a
  model's. The small widget is unchanged.
- **It is computed, not stored**, in `TokenMeterCore` next to `RunOut.swift`: the fraction ahead and the short phrase. It
  is tested without the interface and keeps the conditions of ADR 0038.

## Alternatives that were drawn

- **A line under the window** (A), **one line in the footer** (B), **the mark alone** (D), **the mark with the short phrase**
  (E) and **the gap painted between the bar and the mark** (F). A and B cost height; the mark alone was not readable
  without an explanation; F was not seen working at 10 px.
- **A popover that closes by itself after a timer** with a shrinking line, rejected for an `x`: no time to choose, and
  fewer states to test.
- **A dedicated tutorial page inside the app**, rejected for a docs section: the problems already link the docs.
- **The `i` on each bar row**, rejected: the `i` beside the name was enough.

## Consequences

- **The date is not readable at a glance in the panel.** The mark and its colour are the only cue, and what makes a person
  hover is the `i` text. It is a choice: the date takes space and is not always needed.
- The panel does not grow. ADR 0038 and the Bars page of the docs say the line is a row under the detail: they change
  with the code.
- The widget needs a short form of the sentence ("out Thu 6 pm"), rounded to the hour as the long one is.
- The Design System gains a mark, a close button and a popover, and its `PaceLine` card changes.

## Open

- **A popover opened from inside the menu-bar panel**: not known whether it keeps the panel open.
- **The widget's height**: not seen on screen; the short phrase in the detail line does not add a row, but the widget may
  already cut what is under its first card.
- **The orange text on a light card**: its contrast was not measured. It is the colour of the notice text already in use.
- **The dark appearance** of the mark, the popover and the phrase was not seen when it was drawn.
- **The Learn more target** exists for a person only once the docs are published, and the published docs may be behind the
  code.
