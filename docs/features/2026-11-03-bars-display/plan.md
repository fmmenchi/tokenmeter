---
title: Bars, left or used, plan
sidebar_label: Plan
sidebar_position: 3
---

# Bars, left or used, plan

How the [proposal](./proposal.md) is built, with one line added to [ADR 0006](../../adr/0006-display-preferences.md): the choice is a preference of the app and reaches the widget in the snapshot, as the skin does ([ADR 0013](../../adr/0013-skins.md)). Approved and built on 2026-11-03.

## Where each thing goes

| Layer  | Folder                       | What                                                                                                              |
| :----- | :--------------------------- | :---------------------------------------------------------------------------------------------------------------- |
| Core   | `Sources/TokenMeterCore/`    | `BarsDisplay`: the two cases, the fraction a bar is filled to and the position of the mark; `Snapshot` carries it |
| Tests  | `Tests/TokenMeterCoreTests/` | `BarsDisplayTests.swift`: both rules, the snapshot with it, without it and with a value that is not known         |
| Shared | `Shared/`                    | the environment value, and `WindowRow` and `ScopedWindowRow` drawing the figure, the bar and the mark from it     |
| App    | `App/TokenMeter/`            | the choice in `Meter`, the group in General, the two pages of the wizard                                          |
| Widget | `Widget/TokenMeterWidget/`   | reads the choice from the snapshot, sets it once at the root                                                      |

## The steps

One commit each, three files at most, the gate green (`pnpm run check`, which builds the app and the widget unsigned).

| Step | Commit                                                                                                      | Files                                                                                    |
| :--- | :---------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------- |
| 1    | `feat(core): the bars can be read as left or as used`                                                       | `BarsDisplay.swift`, `Snapshot.swift`, `BarsDisplayTests.swift`                          |
| 2    | `feat(shared): the figure, the bar and the mark of a row follow the choice`                                 | `Shared/UsageViews.swift`, `Shared/BarsDisplayStyle.swift`, `Shared/Skins/SkinBar.swift` |
| 3    | `feat(app): the choice is kept, published and set at the root of the panel and the widget`                  | `Meter.swift`, `MenuContent.swift`, `TokenMeterWidget.swift`                             |
| 4    | `feat(app): General says what the bars show, with a control`                                                | `BarsDisplayGroup.swift`, `SettingsView.swift`                                           |
| 5    | `feat(app): the wizard says where the figure of the bars is chosen`                                         | `Welcome/WelcomePages.swift`                                                             |
| 6    | `docs(use)`: bars, settings and the welcome page                                                            | `use/bars.md`, `use/settings.md`, `use/welcome.md`                                       |
| 7    | `docs(develop)`: the core API and the architecture page                                                     | `develop/core-api.md`, `develop/architecture.md`                                         |
| 8    | Reconcile, on a `docs/` branch: the status, the row to _Implemented_ and, if asked, Views and Design System | `index.md`, `features/index.md`                                                          |

The changelog is written with the release, not here.

## Tests

- `left` fills a bar to the remaining fraction and puts the mark where it is; `used` fills to one minus it and mirrors the mark.
- A window with nothing used is zero in `used` and one in `left`; an unknown window stays unknown in both.
- A snapshot written with `used` reads back as `used`; one without the field, or with a value that is not known, reads as `left`.
- The colour of a window is the same in both readings (it comes from the remaining fraction, which neither case changes).
- The wizard's texts are in the app, which has no test target: pages 2 and 7 were read in the code, and the other five did not change.

## What was added while building

- `percent(remaining:)` in the core, because rounding `used` on its own makes `13% left` and `88% used` of the same window: it is a hundred minus the
  figure of `left`, and the test says every window adds up to 100.
- `emptyIsEmpty` on `QuotaBar` and `SkinBarBody`: three shapes keep a minimum fill at zero, and the stats, which share the bar, keep it too.
- The five skins were drawn offscreen from the real shared views with a throwaway harness, in both readings: `~0% used` is empty in all of them.

## Added in 0.9.1: the stats

One commit for the core (`littleMarginText` and `plentyOfMarginText` on `BarsDisplay`, tested, because the sentences were strings inside a view), one for
`StatsView.swift` (the row of a window and the verdict read the choice from the environment), and the docs. The colour of a row stays on what is left.

## Not verified at the time of writing

- The five skins' bars with the fill inverted: the blocks of Dracula, the thin line of One Dark, the thick pill of Catppuccin and the
  outline of Nord were never drawn with a nearly full bar next to a nearly empty track. The smallest sliver a skin draws for a bar
  with something left must not appear for `~0% used`: that is checked in step 2 on the real views, offscreen.
- The widget in each size with `used`, which needs the install; the mark on the panel, which shows only on the real app.
- That the stats view draws no bar through `WindowRow`: read in step 2, not assumed.
- The wizard page 2 with the control beside the screenshot, on a small display.
