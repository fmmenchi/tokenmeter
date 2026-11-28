---
title: Provider widget, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# Provider widget, proposal

The design that was chosen: one widget per account, with at most two gauges. It was drawn as a canvas in Claude, which is deleted
once the feature is implemented; this page is what stays. The pictures of the canvas are not here yet: they are exported from it
before the canvas goes. **Every number is a sample.**

## Why

Today the widget stacks one card per provider. With two the second card does not fit a medium widget and is clipped, and the small
one cuts its lines short. One widget per account fits, and the person places each where they want it.

## The widget

- **A header**: the card's title, its plan in a capsule in the medium size, and the age of an old reading on the right ("3h ago").
- **A gauge per window, two at most**: the window's label above, the figure inside the ring, the reset under it ("in 3h 20m").
  The ring is filled as far as the bar would be and takes the colour of what is left: green from 40%, orange from 15%, red under.
- **A model's limit stays inside its window**, as in the panel: a thin inner ring in that window's gauge draws the lowest. The small
  widget writes that one under the reset ("Fable 6%"); the medium one lists them all beside the gauges, under "Weekly by model".
- **Small and medium.** The large size is left out: with one card it has nothing to fill it.
- **Only the quota and the reset.** Tokens, the moment a window runs out and the stats stay in the panel.

## States

| State        | What the widget does                                                    |
| :----------- | :---------------------------------------------------------------------- |
| Old reading  | "~" before the figure, the ring at half strength, the age in the header |
| Exhausted    | the ring empty, the reset in the notice colour                          |
| Unknown      | "—" in the ring, no fill                                                |
| No data      | "Open tokenmeter once to publish usage."                                |
| Account gone | the account is no longer a card: the widget asks to choose another one  |

## Skins

A widget takes its skin's panel colour as its ground, as today, and the skin's colours on the rings, the track and the text, with
its typeface. The shape of the skin's bars does not apply: a ring has none.

## The desktop

On the desktop of a Mac the system can draw widgets in its vibrant rendering, which desaturates the gauges' colours. The figure is
always written, so the widget still reads; it was simulated on the canvas and is to be checked on a Mac.

## Also changed

- **The welcome wizard** gets a page, "A widget for each account", after "An account is a folder": nine pages.
- **What's new** says the widget to the people who update.

## Decisions taken in the design

- **One card per widget, not a stack.** The stack is what did not fit.
- **Gauges, at most two**, chosen over a copy of the card and over a big figure with a list: the copy of the card was clear but
  ran out of room with a few model limits, and a big figure beside a list read as two different widgets.
- **The model limits stay grouped under their window.** Drawing them as windows of their own changed how many limits a card seems
  to have.
- **The small widget shows more than the four pieces of information Apple suggests** (WWDC20): two gauges with their resets. It
  was kept because it reads.
- **No provider mark or colour**: the snapshot does not say which tool an account is of ([ADR 0018](../../adr/0018-a-widget-per-account.md)).
