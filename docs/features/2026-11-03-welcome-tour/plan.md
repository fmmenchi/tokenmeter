---
title: Welcome tour, plan
sidebar_label: Plan
sidebar_position: 3
---

# Welcome tour, plan

How the [proposal](./proposal.md) is built, under [ADR 0014](../../adr/0014-welcome-tour.md). Proposed: it waits for Fabio's approval, and
nothing is built before.

## Where each thing goes

| Layer  | Folder                            | What                                                                                                     |
| :----- | :-------------------------------- | :------------------------------------------------------------------------------------------------------- |
| Core   | `Sources/TokenMeterCore/Welcome/` | `WelcomeState`: not started, at a stop, finished, skipped; the transitions; whether a run is a first one |
| Tests  | `Tests/TokenMeterCoreTests/`      | `WelcomeTests.swift`: the transitions, a fresh install and an update, skipping at any stop               |
| Shared | `Shared/Tour/`                    | the stops and their texts, the frame each part reports, the veil with a hole and the caption card        |
| App    | `App/TokenMeter/Welcome/`         | the status item access, the ring and the popover, the end summary, the button in Settings                |

## The steps

One commit each, three files at most, the gate green and `xcodebuild` for the app. Step 2 is a spike on a throwaway branch and its result
is written in the ADR before step 3.

| Step | Commit                                                                                                      | Files                                                                               |
| :--- | :---------------------------------------------------------------------------------------------------------- | :---------------------------------------------------------------------------------- |
| 1    | `feat(core): the state of the welcome tour`                                                                 | `Welcome/WelcomeState.swift`, `WelcomeTests.swift`                                  |
| 2    | the spike: find the status item, draw a ring, open the panel from code                                      | a throwaway branch; the result goes into `docs/adr/0014-welcome-tour.md`            |
| 3    | `feat(app): reach the menu-bar item and open the panel from code`                                           | `Welcome/StatusItemAccess.swift`, `TokenMeterApp.swift`                             |
| 4    | `feat(app): the ring and the popover on the icon`                                                           | `Welcome/IconWelcome.swift`, `Meter.swift`                                          |
| 5    | `feat(app): the veil with a hole and the caption inside the panel`                                          | `Shared/Tour/TourOverlay.swift`, `Shared/Tour/TourStops.swift`, `MenuContent.swift` |
| 6    | `feat(app): the end summary of what the app set up`                                                         | `Welcome/WelcomeSummary.swift`, `MenuContent.swift`                                 |
| 7    | `feat(app): the Settings stop and the button to show the welcome again`                                     | `SettingsView.swift`, `Welcome/SettingsTourOverlay.swift`                           |
| 8    | `docs(use)`: the welcome page and the changelog                                                             | `use/welcome.md`, `use/changelog.md`                                                |
| 9    | `docs(develop)`: the core API, the architecture and AGENTS.md                                               | `develop/core-api.md`, `develop/architecture.md`, `AGENTS.md`                       |
| 10   | Reconcile, on a `docs/` branch: the status, the row to _Implemented_ and, if asked, Views and Design System | `index.md`, `features/index.md`                                                     |

## Tests

- A fresh install starts the tour; an app that already ran does not, and the tour is still available from Settings.
- Skip at any stop ends it, and it is not started again by itself.
- Closing the panel in the middle leaves the tour where it was, and the next opening goes on from there.
- Each stop is drawn offscreen, in both appearances, with the real views of the panel, and looked at.

## Not verified at the time of writing

Reaching the status item and opening the panel from code, the ring on the icon, the popover under it, the tour on a small display, and
the Settings stop. The first two are what the spike answers.
