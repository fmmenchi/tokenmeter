---
title: Settings in tabs, plan
sidebar_label: Plan
sidebar_position: 3
---

# Settings in tabs, plan

How the [proposal](./proposal.md) is built. It is a change of where the sections of Settings sit, inside the app target, so it needs
no ADR. Accepted when Fabio asked to do it and to release it.

## How

The window is a row of tab buttons drawn by the app, not a `TabView`: in a plain `Window` a `TabView` is drawn as a segmented
control, not as the icon over a name of System Settings. The selected tab chooses which section the existing `Form` shows; the
sections themselves, `NotificationsGroup`, `UpdatesGroup` and `SkinGroup`, are not changed, except that `SkinGroup` becomes a grid
of tiles. The `Form` has a fixed height and scrolls when a section is taller.

## The steps

One commit each, three files at most, the gate green and `xcodebuild` for the app.

| Step | Commit                                                                                                      | Files                                      |
| :--- | :---------------------------------------------------------------------------------------------------------- | :----------------------------------------- |
| 1    | `feat(app): Settings in tabs`                                                                               | `SettingsView.swift`, `SettingsTabs.swift` |
| 2    | `feat(app): the skins as a grid of tiles`                                                                   | `SkinGroup.swift`, `SkinPreview.swift`     |
| 3    | `docs(use)`: the changelog and the skins page                                                               | `use/changelog.md`, `use/skins.md`         |
| 4    | Reconcile, on a `docs/` branch: the status, the row to _Implemented_ and, if asked, Views and Design System | `index.md`, `features/index.md`            |

## Not verified at the time of writing

The tabs and the grid in the real window, in both appearances; the height of the window on a small display.
