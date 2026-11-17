---
title: Loading skeleton, plan
sidebar_label: Plan
sidebar_position: 3
---

# Loading skeleton, plan

How the [proposal](./proposal.md) is built. **No ADR: nothing structural.** Only the views change: nothing is stored, the core is not
touched, and the waits are the ones the app already had.

## Where each thing goes

| Layer | Folder            | What                                                                                 |
| :---- | :---------------- | :----------------------------------------------------------------------------------- |
| App   | `App/TokenMeter/` | `LoadingSkeleton.swift` draws the empty cards; `MenuContent` and `StatsView` show it |
| Docs  | `docs/use/`       | the bars page and the stats page say what the panel draws while it waits             |

## The rules, as built

- **The skeleton appears after 300 ms.** A wait shorter than that, as the stats after a restart, read from what is kept, shows nothing
  rather than a flash.
- **One skeleton for every wait of the stats**: opening the history, reading the logs the first time, no snapshot yet. It is the same
  view in the same place, so it is not drawn again when the wait changes; only the line above it comes and goes.
- **The line is shown only while the logs are read**, the one wait that is long.
- **Cards**: one for each provider of the snapshot, two when there is none yet.
- **Colour and shape**: the skin's track colour (the system's 15% where there is no skin), the card's chrome (`cardChrome`), and each
  window's bar is the real `QuotaBar` with no fill, so it takes the skin's shape.
- **Motion**: a fade between full and 40% strength over 1.4 s. With Reduce Motion it stands still.
- **VoiceOver** reads the line, or "Loading", once: the shapes are hidden from it.

## The steps

| Step | Commit                                                                           | Files                                                           |
| :--- | :------------------------------------------------------------------------------- | :-------------------------------------------------------------- |
| 1    | `feat(app): a skeleton of the cards replaces the spinner while the data arrives` | `LoadingSkeleton.swift`, `MenuContent.swift`, `StatsView.swift` |
| 2    | `docs(use): the panel and the stats draw empty cards while the data arrives`     | `use/bars.md`, `use/stats.md`                                   |
| 3    | `docs(features)`: this folder and its row                                        | `index.md`, `proposal.md`, `plan.md`, `features/index.md`       |

The changelog is written with the release.

## Tests

The views are in the app, which has no test target. The skeleton was drawn offscreen in the five skins, dark and light, with the
`@State` that delays it set to shown; the gate builds the app.

## Not verified at the time of writing

- The pulse and the 300 ms delay on screen: an offscreen render draws one still frame.
- The skeleton with Reduce Motion on.
- The panel before its first reading on a real launch: it lasts a moment and was not caught.
