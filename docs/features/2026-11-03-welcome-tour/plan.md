---
title: Welcome tour, plan
sidebar_label: Plan
sidebar_position: 3
---

# Welcome tour, plan

How the [proposal](./proposal.md) is built. Accepted on 2026-11-03: Fabio said to go on. Built as below; the pictures are the docs' screenshots, not a script. There is no ADR: nothing moves
a boundary.

## Where each thing goes

| Layer | Folder                            | What                                                                                             |
| :---- | :-------------------------------- | :----------------------------------------------------------------------------------------------- |
| Core  | `Sources/TokenMeterCore/Welcome/` | `WelcomeState`: the seven pages, Back, Next, Skip, Done, close, and whether it counts as seen    |
| Tests | `Tests/TokenMeterCoreTests/`      | `WelcomeTests.swift`: the transitions, a fresh install and an update, skip and close at any page |
| App   | `App/TokenMeter/Welcome/`         | the window, the pages, the pictures' assets, and the button in Settings                          |

The wizard needs nothing of the `Meter`: it is the part of the app that is isolated, and it is opened by an `NSWindow` hosting a SwiftUI view,
not by a scene, so it can open by itself at the first launch. The menu-bar item stays as it is.

## The steps

One commit each, three files at most (the pictures count as one concern), the gate green and `xcodebuild` for the app.

| Step | Commit                                                                                                      | Files                                                                                                                 |
| :--- | :---------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------- |
| 1    | `feat(core): the welcome is a wizard of seven pages`                                                        | `Welcome/WelcomeState.swift`, `WelcomeTests.swift` (the first version of both is in, built for a tour over the panel) |
| 2    | `feat(app): the pictures of the welcome, the panel and the stats`                                           | `Assets.xcassets` (the two screenshots of `docs/assets`, with their sample data)                                      |
| 3    | `feat(app): the window of the welcome and its seven pages`                                                  | `Welcome/WelcomeWindow.swift`, `Welcome/WelcomePages.swift`, `TokenMeterApp.swift`                                    |
| 4    | `feat(app): a button in General shows the welcome again`                                                    | `SettingsView.swift`                                                                                                  |
| 5    | `docs(use)`: the welcome page and the changelog                                                             | `use/welcome.md`, `use/changelog.md`                                                                                  |
| 6    | `docs(develop)`: the core API and AGENTS.md                                                                 | `develop/core-api.md`, `AGENTS.md`                                                                                    |
| 7    | Reconcile, on a `docs/` branch: the status, the row to _Implemented_ and, if asked, Views and Design System | `index.md`, `features/index.md`                                                                                       |

## Tests

- A fresh install and the first update both open it, and neither opens it again once it was finished, skipped or closed.
- Back at the first page does nothing; Next at the last page is Done.
- Quitting in the middle leaves it unseen.
- Each page was opened from a debug build and looked at in the dark appearance of the author's Mac; the pictures are the docs' light screenshots.

## Not verified at the time of writing

That a window opens by itself at the first launch of a menu-bar-only app (step 2 starts with that), how the pictures look on a Retina display and
in both appearances, the wizard on a small display, and the first-update case with a real update.
