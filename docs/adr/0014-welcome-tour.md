# ADR 0014 — Welcome tour: the app reaches its own menu-bar item to point at it, and the tour is drawn inside the panel

Status: accepted (2026-11-03, with the plan of the [welcome tour](../features/2026-11-03-welcome-tour/plan.md); Fabio approved both and the rule that the tour starts once, on a new install and on the first update)

## Context

The [chosen design](../features/2026-11-03-welcome-tour/proposal.md) has the app point at its own icon, open its panel by itself and walk
the person over the panel. [ADR 0001](./0001-app-architecture.md) made the menu-bar item a SwiftUI `MenuBarExtra` in its window style. That
scene gives the app no handle on the status item, its button or its panel, and no call to open it. The design needs three things from
outside SwiftUI's reach: a ring and a popover anchored to the icon, a way to open the panel, and a caption inside the panel's own window
(the panel is 300 points wide, so a bubble beside it would need a window of its own). How the app does this is structural: it decides
whether the menu-bar item stays a `MenuBarExtra`.

## Decision

- **Amended on 2026-11-03 by [ADR 0015](./0015-status-item-in-appkit.md):** the spike showed the panel cannot be opened from code with
  a `MenuBarExtra`, so the menu-bar item becomes an `NSStatusItem` and the next point no longer holds. The rest of this ADR stands.
- **The menu-bar item stays a `MenuBarExtra`**, and the app reaches its status item by looking for the status-bar window among
  `NSApp.windows` and the button inside it, in one small file of the app target. The ring and the popover are added to that button; the
  panel is opened by performing a click on it. Nothing in the app depends on this except the tour: if the item is not found, there is no ring,
  no popover and no tour, and the panel works as before.
- **A spike comes first**, on a throwaway branch: find the item, draw a ring on it, open the panel, on the macOS the author has. If it
  does not work, this ADR is revised before any other step: the alternative is to replace the `MenuBarExtra` with an AppKit `NSStatusItem`
  hosting the same SwiftUI panel, which is an amendment of ADR 0001 and its own decision.
- **The tour is drawn in SwiftUI inside the panel**: each part of the panel that a stop explains reports its frame, and one overlay draws
  the veil with a hole over it and the caption card in the panel's own window. The stop that is about Settings uses a small overlay of its
  own in the Settings window.
- **The state of the tour is a pure value in `TokenMeterCore`** (not started, at a stop, finished, skipped), with its transitions tested.
  The defaults hold only that it was seen.
- **The tour starts by itself once, when it was never seen**: the first time the app opens a version that has it, on a fresh install
  and on the first update alike. The defaults hold one flag, set when the tour is finished or skipped, never when it is only started,
  so a tour that was interrupted starts again at the next opening of the panel. After that it is one button away in Settings.
- **Nothing leaves the Mac** and nothing is asked: the tour uses no network and no credential.

What the stops say, their order and their count are the feature's, in its
[proposal](../features/2026-11-03-welcome-tour/proposal.md), and change without an ADR.

## Consequences

- **A person who already uses the app sees the tour once, after the update**, with the panel open on their own bars. The first-launch
  wording (the icon is introduced, the bars are said to be empty until the first use) is then not true for them: the wording has to hold
  for both, or the tour has to look at what the panel holds. That is the feature's to decide, in its proposal.
- After an update Sparkle relaunches the app, so the popover can come up in the middle of someone's work: it is skippable and it happens
  once.
- The tour depends on how macOS builds the status item, which Apple does not document: a new macOS may break the ring and the popover. The
  cost is bounded (the tour does not start) and the check is one file.
- The tour state is tested in the core, which the gate builds; the overlay and the popover are in the app target, which only `xcodebuild`
  builds, so the overlay is drawn offscreen for each stop and each appearance and looked at, and the popover on the icon needs a look on a Mac.
- Not verified at the time of writing: that the status item and its button can be reached on the author's macOS, that a click performed from
  code opens the panel, that a ring can be drawn on the button without changing the icon, and that the Settings window can host its own overlay.
