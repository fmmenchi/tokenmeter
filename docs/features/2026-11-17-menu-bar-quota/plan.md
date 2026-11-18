---
title: Quota in the menu bar, plan
sidebar_label: Plan
sidebar_position: 3
---

# Quota in the menu bar, plan

How the [proposal](./proposal.md) is built. **No ADR: nothing structural.** The figures are read from the snapshot the panel
already draws, in the order and with the visibility it already has (ADR 0006); one preference is added; the views stay in the
app. Nothing is read from outside the app and no boundary moves.

## The rules

- **A choice in Settings › General, on at first** (the author, 2026-11-18, first off, then on): "Show the quota in the menu bar". Off, the bar is the
  gauge alone, as today.
- **One figure per card**, in the order of the panel, a hidden card left out: the cards are `Snapshot.applying(_:)`, as the
  panel shows them. Several accounts of one tool are several cards, so several figures: the snapshot does not say which tool an
  account is of, and grouping them would need it (to confirm with the author: the proposal drew one figure per provider).
- **The tightest window of a card** is the one with the least left among the windows the card shows, as they read now
  (`ProviderSnapshot.resolved(_:at:)`). Model limits do not count: they are a part of a window of the card. A window with no
  figure does not count; a card with none shows "—", the dash the panel writes.
- **The figure is the panel's**: `figureText(_:at:)`, so Left or Used, rounding and "~" for an old or inferred reading are the
  same as on the bars. It is plain text in the bar's colour; the red of the proposal is not used, because the label of a menu
  bar item is drawn by the system as a template and its colour is not ours to set (to confirm when it is built).
- **VoiceOver says the figures in words**, the cards in order: "Claude 31% left · ChatGPT 99% left"; an old reading
  "Claude about 31% left, 25m ago" (the panel's `observedAgoText`); no figure "ChatGPT no figure yet". With the dot,
  "needs attention" comes first, as today.
- **A crowded bar**: macOS hides an item that does not fit and does not say so to the app, so it cannot be detected. With more
  than three cards the bar shows one figure, the tightest of all, and VoiceOver says "the tightest". The number three is a
  guess, to be checked on a real bar.
- **When it redraws**: with every new snapshot, as the gauge does. A `TimelineView` that redrew it every minute left the
  menu-bar item empty (seen on the author's Mac, 2026-11-18), so "~" appears with the next snapshot after a reading turns old.

## Where each thing goes

| Layer | Folder                       | What                                                                                   |
| :---- | :--------------------------- | :------------------------------------------------------------------------------------- |
| Core  | `Sources/TokenMeterCore/`    | `MenuBarFigures`: the tightest window of a card, the figures, the one figure, the text |
| Tests | `Tests/TokenMeterCoreTests/` | `MenuBarFiguresTests.swift`                                                            |
| App   | `App/TokenMeter/`            | the preference in `Meter`, the row in General, the label beside the gauge              |
| Docs  | `docs/use/`                  | what it does, settings                                                                 |

`figureText` and `observedAgoText` live in `Shared/` and in the core; step 1 moves what the text needs into the core, so the
rule is tested there and the app only draws it.

## The steps

| Step | Commit                                                                         | Files                                                                                                                                                           |
| :--- | :----------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | `feat(core): the menu bar figures, one per card, and the text that names them` | `MenuBarFigures.swift`, `MenuBarFiguresTests.swift`                                                                                                             |
| 2    | `feat(app): a choice in settings shows the quota in the menu bar`              | `Meter.swift`, `MenuBarGroup.swift`, `SettingsView.swift`                                                                                                       |
| 3    | `feat(app): the figures beside the gauge, with a tooltip`                      | `TokenMeterApp.swift`, `MenuBarLabel.swift`                                                                                                                     |
| 4    | `docs(use): the quota in the menu bar`                                         | `use/what-it-does.md`, `use/settings.md`                                                                                                                        |
| 5    | Reconciliation, on a `docs/` branch once the code is in `main`                 | `design-export` of the menu bar item and the Design System's rule "carries no percentage", the status, the row to _Implemented_, the offer to delete the canvas |

## Tests

The tightest window is the least left; a model limit does not count; a window with no figure does not count; a card with none
gives "—"; Left and Used give the panel's figures; "~" for a stale reading and for a reset one; the order and the hidden cards
follow the preferences; more than three cards give one figure, the tightest of all; the text names every card in order, says
"about" and the age of an old reading, "no figure yet", and puts "needs attention" first.

## What changed while building

- **No tooltip** (the author, 2026-11-18): `.help()` on the label of a `MenuBarExtra` is not shown, and the status item's button
  in AppKit was ruled out. The names are in the panel, in the same order, and in what VoiceOver says.
- **No timeline**: a `TimelineView` in the label left the menu-bar item empty; the label redraws with each snapshot.
- **On at first** (the author, 2026-11-18), where the plan said off.
- The label draws the gauge and the text side by side: seen on the author's Mac, dark menu bar.

## Not verified at the time of writing

- The light menu bar, and the order of the figures after the cards are reordered.
- How many figures fit before macOS hides the item, on a real bar with other items.
- The figure's width as it changes (`8%` to `100%`): the digits are tabular, the item may still move the others by a few points.
