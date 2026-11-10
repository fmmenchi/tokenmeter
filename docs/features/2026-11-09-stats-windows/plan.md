---
title: Stats, windows as strips, plan
sidebar_label: Plan
sidebar_position: 3
---

# Stats, windows as strips, plan

How the [proposal](./proposal.md) is built. **No ADR: nothing structural.** The verdict stays a pure function of the facts in the core
([ADR 0010](../../adr/0010-usage-stats.md)), the views stay in the app, and nothing new is stored: the strips are drawn from the
readings the store already keeps. A word is added to the verdict, and the rule that said it never says Move up goes with it. Approved by
the author on 2026-11-09.

## Where each thing goes

| Layer | Folder                       | What                                                                                                                        |
| :---- | :--------------------------- | :-------------------------------------------------------------------------------------------------------------------------- |
| Core  | `Sources/TokenMeterCore/`    | `UsageStats`: the 5 hours count in the verdict, `Verdict.Word.moveUp` and its reason, the slots of a weekly strip, the days |
| Tests | `Tests/TokenMeterCoreTests/` | `UsageStatsTests.swift`: the new verdict rules, the 14 days of the short windows, the slots and the days                    |
| App   | `App/TokenMeter/`            | `StatsView.swift` loses the rows; `StatsStrips.swift` draws the strips; the verdict box, the notice, the wizard pages       |
| Docs  | `docs/use/`, `docs/develop/` | the stats page, the welcome page and the core API                                                                           |

## The rules, as built

- **Windows shorter than a day look at the last 14 days**, whatever the range, so the 5-hour strip and the numbers above it are the same
  14 days. A window of a day or longer looks at the range.
- **A window length counts in the verdict** once it has ended `windowsNeeded` times: 4 for a day or longer, 12 for a shorter one.
- **Move up**: in a counting window length the ceiling was reached at least twice and in at least 15% of the windows. The window that
  went there most often is named. Otherwise the rules are those of today: Stay when the ceiling was reached, Stay when a reading may
  have ended lower, Move down at 60% left or more, Stay for the rest.
- **A weekly strip has a block for each window of the range**: 4 for a month, 13 for 3 months, 52 for a year, and for Lifetime as many as
  fit between the first thing kept and now, at most 104. A window the app did not see is an empty slot, drawn dashed.
- **The weekly is not known** when the weekly window is in the snapshot with no figure. A notice says so, and the verdict says it
  counts the 5 hours alone.

## The steps

One commit each, three files at most, the gate green (`pnpm run check`).

| Step | Commit                                                                                           | Files                                                   |
| :--- | :----------------------------------------------------------------------------------------------- | :------------------------------------------------------ |
| 1    | `feat(core): the 5 hours count in the verdict and it can say move up`                            | `UsageStats.swift`, `UsageStatsTests.swift`             |
| 2    | `feat(app): the stats draw each window as a strip with the figure in a tooltip`                  | `StatsView.swift`, `StatsStrips.swift`                  |
| 3    | `feat(app): the wizard describes the strips and the four words of the suggestion`                | `Welcome/WelcomePages.swift`, the picture of the stats  |
| 4    | `docs(use)`: the stats and the welcome page; `docs(develop)`: the core API                       | `use/stats.md`, `use/welcome.md`, `develop/core-api.md` |
| 5    | Reconcile, on a `docs/` branch: the status, the row to _Implemented_ and, if asked, Views and DS | `index.md`, `features/index.md`                         |

The changelog is written with the release, not here.

## Tests

- Four weekly windows that reached the ceiling twice are not Move up (4 is the minimum and 2 of 4 is 50%: it is Move up); one of 5 is
  Stay, and two of 20 is Stay (10%). The window with the highest share is the one named.
- A 5-hour window length with fewer than 12 windows does not count; with 12 it does, and Move up can come from it.
- The 5-hour numbers are those of the last 14 days even when the range is a year.
- The slots of a weekly strip: as many as the range says, the seen windows in their place, the others empty, the newest slot being the
  latest boundary before now, and a window ending a few minutes off its boundary landing in the same slot.
- The days of a short window: 14 columns, oldest first, each with its windows oldest first.
- The wizard's text and the views are in the app, which has no test target: they are read in the code, and built by the gate.

## Not verified at the time of writing

- That the system's tooltip shows on a block in the `MenuBarExtra` panel.
- The strips with 52 blocks, in the other skins, light and dark, and at the width of the panel.
- That a weekly window with no figure is what the snapshot holds when Claude's `seven_day` is missing; a weekly turned off in Settings
  must not show the notice.
- The thresholds of Move up are a choice and not a measurement, as the 60% of Move down is.
