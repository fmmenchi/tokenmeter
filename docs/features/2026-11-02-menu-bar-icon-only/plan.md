---
title: Menu bar icon only, implementation plan
sidebar_label: Implementation plan
sidebar_position: 3
---

# Menu bar icon only, implementation plan

How the bar stops showing text and shows a dot, and the order it is built in. There is no ADR: nothing structural changes.

## The pieces

| Piece                  | Change                                                                                                |
| :--------------------- | :---------------------------------------------------------------------------------------------------- |
| `MenuBarIcon`          | A second template image, the gauge with a dot cut out of its top right corner by clearing the pixels. |
| `Meter.needsAttention` | Replaces `menuBarTitle`: true while the panel lists a problem.                                        |
| `TokenMeterApp`        | The label is the image alone, named for screen readers, with or without the dot.                      |
| Settings               | The note about the percentage in the menu bar is removed.                                             |

## Order

| Step | Commit                                                          | Files                                                             |
| :--- | :-------------------------------------------------------------- | :---------------------------------------------------------------- |
| 1    | `feat(app): the menu bar is the icon, with a dot for a problem` | `MenuBarIcon.swift`, `Meter.swift`, `TokenMeterApp.swift`         |
| 2    | `fix(app): drop the note about the menu bar percentage`         | `SettingsView.swift`                                              |
| 3    | `docs(use): the menu bar is an icon with a dot`                 | `what-it-does.md`, `configure-providers.md`, `troubleshooting.md` |
| 4    | Reconciliation, on a `docs/` branch after the merge             | the Views, the status, the row in the list                        |

## Tests and checks

- There is no unit test for the title: it lived in the app target, which the gate does not build. The gate is
  `pnpm run check` plus `xcodebuild` of the app.
- **Not checked in a test**: how the dot looks on a real menu bar, light and dark, at 1x and 2x. The preview shows it.
