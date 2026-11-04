---
title: Bars, left or used, plan
sidebar_label: Plan
sidebar_position: 3
---

# Bars, left or used, plan

How the [proposal](./proposal.md) is built, with one line added to [ADR 0006](../../adr/0006-display-preferences.md): the choice is a preference of the app and reaches the widget in the snapshot, as the skin does ([ADR 0013](../../adr/0013-skins.md)). Proposed on 2026-11-03: nothing is built.

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

| Step | Commit                                                                                                      | Files                                                           |
| :--- | :---------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------- |
| 1    | `feat(core): the bars can be read as left or as used`                                                       | `BarsDisplay.swift`, `Snapshot.swift`, `BarsDisplayTests.swift` |
| 2    | `feat(shared): the figure, the bar and the mark of a row follow the choice`                                 | `Shared/UsageViews.swift`, `Shared/BarsDisplayStyle.swift`      |
| 3    | `feat(app): the choice is kept, published and set at the root of the panel and the widget`                  | `Meter.swift`, `MenuContent.swift`, `TokenMeterWidget.swift`    |
| 4    | `feat(app): General says what the bars show, with a control`                                                | `BarsDisplayGroup.swift`, `SettingsView.swift`                  |
| 5    | `feat(app): the wizard says where the figure is chosen`                                                     | `Welcome/WelcomePages.swift`, `WelcomeTests.swift`              |
| 6    | `docs(use)`: bars, settings and the welcome page                                                            | `use/bars.md`, `use/settings.md`, `use/welcome.md`              |
| 7    | `docs(develop)`: the core API and the architecture page                                                     | `develop/core-api.md`, `develop/architecture.md`                |
| 8    | Reconcile, on a `docs/` branch: the status, the row to _Implemented_ and, if asked, Views and Design System | `index.md`, `features/index.md`                                 |

The changelog is written with the release, not here.

## Tests

- `left` fills a bar to the remaining fraction and puts the mark where it is; `used` fills to one minus it and mirrors the mark.
- A window with nothing used is zero in `used` and one in `left`; an unknown window stays unknown in both.
- A snapshot written with `used` reads back as `used`; one without the field, or with a value that is not known, reads as `left`.
- The colour of a window is the same in both readings (it comes from the remaining fraction, which neither case changes).
- The wizard's two pages name the choice, and the other five texts do not change.

## Not verified at the time of writing

- The five skins' bars with the fill inverted: the blocks of Dracula, the thin line of One Dark, the thick pill of Catppuccin and the
  outline of Nord were never drawn with a nearly full bar next to a nearly empty track. The smallest sliver a skin draws for a bar
  with something left must not appear for `~0% used`: that is checked in step 2 on the real views, offscreen.
- The widget in each size with `used`, which needs the install; the mark on the panel, which shows only on the real app.
- That the stats view draws no bar through `WindowRow`: read in step 2, not assumed.
- The wizard page 2 with the control beside the screenshot, on a small display.
