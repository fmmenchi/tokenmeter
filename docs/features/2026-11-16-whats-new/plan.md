---
title: What's new, plan
sidebar_label: Plan
sidebar_position: 3
---

# What's new, plan

How the [proposal](./proposal.md) is built. **No ADR**: nothing is stored but one more preference, nothing is read from outside the
app, and the views stay in the app.

## The rules

- **The entries are written in the app**, one per feature: the version that shipped it, a title and two lines
  (`WhatsNew.entries` in the core). A fix has no entry. Writing the entry is a step of the release of a version that has features.
- **"Last version seen"** is kept in the defaults. At launch, with the installed version newer than it, the entries in between are the
  new features; with none, the card is not shown. The card's buttons, or the window's Done, set it to the installed version.
- **The first launch** shows the welcome, not the card, and sets the last version seen.
- **A person who updates to the first version with this feature** has no last version seen: the card shows the features of that
  version only, because the version they came from is not known.
- Versions compare by number (`0.9.2` before `0.10.0`), not as text.

## Where each thing goes

| Layer | Folder                       | What                                                                                 |
| :---- | :--------------------------- | :----------------------------------------------------------------------------------- |
| Core  | `Sources/TokenMeterCore/`    | `WhatsNew`: the entries, the comparison of versions, which entries are new           |
| Tests | `Tests/TokenMeterCoreTests/` | `WhatsNewTests.swift`                                                                |
| App   | `App/TokenMeter/`            | the card in the panel, the window, the row in Settings › General, the welcome's rule |
| Docs  | `docs/use/`, `docs/develop/` | the welcome and updates pages, the release steps                                     |

## The steps

| Step | Commit                                                                          | Files                                                               |
| :--- | :------------------------------------------------------------------------------ | :------------------------------------------------------------------ |
| 1    | `feat(core): the entries of the new features and which are new since a version` | `WhatsNew.swift`, `WhatsNewTests.swift`                             |
| 2    | `feat(core): the welcome opens on the first launch only`                        | `WelcomeState.swift` and its tests                                  |
| 3    | `feat(app): a card in the panel says what is new and opens the list`            | `WhatsNewNotice.swift`, `WhatsNewWindow.swift`, `MenuContent.swift` |
| 4    | `feat(app): the last version seen, and show what's new again in settings`       | `Meter.swift`, `TokenMeterApp.swift`, the General tab               |
| 5    | `docs`: the use pages and the release steps; then the feature folder's status   | `use/welcome.md`, `use/updates.md`, `develop/…`                     |

## Tests

Versions compare as numbers; the entries between two versions, both ends right; none when nothing new; none on a first launch;
only the installed version's own when the last seen is unknown.

## Not verified at the time of writing

- The card after a real update through Sparkle: it can only be seen by updating from a version that has the feature.
