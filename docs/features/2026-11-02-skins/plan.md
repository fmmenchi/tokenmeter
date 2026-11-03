---
title: Skins, plan
sidebar_label: Plan
sidebar_position: 3
---

# Skins, plan

How the [proposal](./proposal.md) is built, under [ADR 0013](../../adr/0013-skins.md). Accepted when Fabio asked to carry the
feature to the end and to release it.

## Where each thing goes

| Layer  | Folder                          | What                                                                                                                |
| :----- | :------------------------------ | :------------------------------------------------------------------------------------------------------------------ |
| Core   | `Sources/TokenMeterCore/Skins/` | `Skin`, its palettes for both appearances, the bar shapes and the typefaces; the snapshot gains the skin            |
| Tests  | `Tests/TokenMeterCoreTests/`    | `SkinsTests.swift`: the palettes, the legibility of the text, the snapshot with and without a skin                  |
| Shared | `Shared/Skins/`                 | the style in the environment, the five bars, the preview of a skin                                                  |
| App    | `App/TokenMeter/`               | `Meter` keeps the choice, `MenuContent` and the widget apply it, `SkinGroup` in Settings, the stats use its colours |

## The steps

One commit each, three files at most, the gate green and `xcodebuild` when the app or the widget changed.

| Step | Commit                                                                                                      | Files                                                                     |
| :--- | :---------------------------------------------------------------------------------------------------------- | :------------------------------------------------------------------------ |
| 1    | `feat(core): the skins and their palettes, and the snapshot carries the skin`                               | `Skins/Skin.swift`, `Snapshot.swift`, `SkinsTests.swift`                  |
| 2    | merged into step 1: the palettes and the snapshot field are one commit                                      |                                                                           |
| 3    | `feat(app): a skin as a style in the environment`                                                           | `Shared/Skins/SkinStyle.swift`, `UsageViews.swift`                        |
| 4    | `feat(app): the bar in five shapes`                                                                         | `Shared/Skins/SkinBar.swift`, `UsageViews.swift`                          |
| 5    | `feat(app): the card, the pace tick and the type follow the skin`                                           | `ProviderCard.swift`, `PaceTick.swift`                                    |
| 6    | `feat(app): the panel and the widget wear the skin`                                                         | `Meter.swift`, `MenuContent.swift`, `TokenMeterWidget.swift`              |
| 7    | `feat(app): the Skin group in Settings, with a preview of each`                                             | `SkinGroup.swift`, `SettingsView.swift`, `Shared/Skins/SkinPreview.swift` |
| 8    | `feat(app): the stats take the quota colours of the skin`                                                   | `StatsView.swift`                                                         |
| 9    | `docs(use)`: the skins and the licences                                                                     | `use/skins.md`, `use/licenses.md`, `use/changelog.md`                     |
| 10   | `docs(develop)`: the core API, the architecture, AGENTS.md                                                  | `develop/core-api.md`, `develop/architecture.md`, `AGENTS.md`             |
| 11   | Reconcile, on a `docs/` branch: Views and Design System with the code, the status, the row to _Implemented_ | `design-export`, `index.md`, `features/index.md`                          |

## Tests

- Every skin has a palette in the dark and in the light appearance, except System, which has none.
- A palette is exactly the one the [licences page](../../use/licenses.md) lists: the numbers are the theme's, checked one by one.
- The text can be read on the card in every palette: a contrast of at least 4.5 : 1.
- A snapshot with a skin round-trips; one without, and one with an id nobody knows, is System.
- The views are drawn offscreen with the real code for each skin, in both appearances, and looked at.

## Not verified at the time of writing

The solid panel over the real window material, the widget with a solid container in every family and appearance, and how the
five look at the widget's size.
