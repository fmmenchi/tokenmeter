---
name: widget-figma
description: >-
  Keeps the tokenmeter widget (and the menu-bar panel's bars) aligned with a Figma file, in both
  directions: builds them in Figma from the SwiftUI views, or changes the SwiftUI views to match a
  design change. Always writes a short proposal first and waits for a yes. Use when asked to put the
  widget on Figma, import or implement a design of it, or check whether Figma and the widget still
  match.
---

# widget-figma

The SwiftUI views are the source; Figma is the copy unless Fabio says otherwise. Fabio is the
reader: answer in Italian, address him as Fabio.

## 1. Read, then propose. Do not act yet

Read what exists, only what the task needs:

- the views: `Widget/TokenMeterWidget/TokenMeterWidget.swift`, `Shared/UsageViews.swift`
  (`ProviderBlock`, the bar, its colour rule), `App/TokenMeter/MenuContent.swift` for the panel;
- the states the views must show: [Reading the Bars](../../../docs/use/bars.md) (fresh, stale `~`,
  inferred reset, consumption only, the orange notice line) and the data in `Sources/TokenMeterCore/Snapshot.swift`;
- the Figma file, if Fabio named one (a figma.com link): its pages, frames and existing components.

Then write the **proposal**, ten lines at most, and stop:

- **Direction**: code to Figma, or Figma to code. If Fabio did not say, propose one and say why.
- **What will be created or changed**: frames (widget small and medium, the panel), components, and
  the states each one covers.
- **What will not be touched**: anything already in the Figma file that the proposal does not name.
- **Differences found** (Figma to code, or a re-check): one line each, value in the code against value in Figma.
- **Unknown**: what you could not read (a missing file, an unreachable Figma).

Wait. Only an explicit yes starts the work. A correction revises the proposal; it is not a yes.

## 2. Act on the yes

- **Code to Figma.** Load `figma-use`, then `figma-generate-design` (and `figma-swiftui` for the
  SwiftUI side). Take every value from the code at the moment you build: the colour thresholds, the
  tints, fonts, spacing, corner radii. Do not copy a value into the Figma file from memory or from
  this skill. Create components for the bar and the provider block, then the widget frames from them.
  Create into a new page or file unless the proposal named existing frames.
- **Figma to code.** Load `figma-design-to-code` and `figma-swiftui`. Change only the views and
  only the differences the proposal listed. Keep the existing code style. Do not touch the core
  (`Sources/TokenMeterCore`) for a visual change; if a design needs data the snapshot lacks, say so
  and stop, because that needs an ADR.

## 3. Verify and report

- Code changed: `pnpm run check`, then build the app and widget with `xcodebuild` (the gate does not).
  Look at the result on screen if you can; capture only TokenMeter windows.
- Figma changed: take a screenshot of each frame you made and compare it with the states listed.
- Report what you verified against what you assumed, what you left untouched, and the Figma link.
- Never push, never work on `main`, one conventional commit per change, as in `AGENTS.md`.
