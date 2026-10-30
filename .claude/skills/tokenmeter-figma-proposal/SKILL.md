---
name: tokenmeter-figma-proposal
description: >-
  Writes the proposal that comes before any work between the tokenmeter widget (SwiftUI) and Figma,
  then waits for Fabio's yes. Use first, whenever a tokenmeter view (the widget, Settings, the panel) is to be put on
  Figma, taken from Figma, or checked against it. tokenmeter-figma-export and tokenmeter-figma-import run only after it.
---

# tokenmeter-figma-proposal

Nothing is created in Figma and no view is edited until Fabio says yes to a proposal from this skill.
Answer in Italian and address him as Fabio. The SwiftUI views are the source; Figma is the copy unless
Fabio says otherwise.

## 1. Read only what the task needs

- The views. Do not trust a fixed list: find them with
  `grep -rln ": View" App Widget Shared --include=*.swift` and read the ones the task names. Today
  they are the **widget** (`Widget/TokenMeterWidget/TokenMeterWidget.swift` and `Shared/UsageViews.swift`:
  `ProviderBlock`, the bar, its colour rule), the **Settings** window (`App/TokenMeter/SettingsView.swift`)
  and the menu-bar panel (`App/TokenMeter/MenuContent.swift`); there will be more. Say in the proposal
  which views are in scope and which you left out, and why.
- The states a view must show, for the widget and the panel: [Reading the Bars](../../../docs/use/bars.md) (fresh, stale `~`,
  inferred reset, consumption only, the orange notice line) and `Sources/TokenMeterCore/Snapshot.swift`.
  For Settings, the states of its switches and captions in `SettingsView.swift`.
- The Figma file, if Fabio gave a figma.com link: its pages, frames and components.

## 2. Write the proposal, ten lines at most, and stop

- **Direction**: export (code to Figma) or import (Figma to code). If Fabio did not say, propose one and why.
- **Create or change**: one frame set per view in scope (the widget in small and medium, a window, a panel), components, the states each covers.
- **Not touched**: anything in the Figma file or the code that the proposal does not name.
- **Differences**: one line each, the value in the code against the value in Figma, when both exist.
- **Unknown**: what could not be read (no link, a Figma that does not answer, a view not found).

## 3. In Figma: the Proposals section

The Figma file has two sections, and this skill owns the second:

- **Views**: what the code looks like now. Written only by `tokenmeter-figma-export`.
- **Proposals**: what could change. With a Figma link, draw each proposed design here as frames named
  `Proposal <yyyy-mm-dd> · <view> · <title>`, built with `figma-use` (load it first). Create the section
  if it is missing. It is additive: never edit or delete another proposal, and never touch **Views**.

Write the text proposal first, naming the frames; then draw them. The drawing is only the proposal, so it
is allowed before the yes, and it is the only thing that is.

## 4. The gate

Only an explicit yes goes on, to `tokenmeter-figma-export` or `tokenmeter-figma-import` as the direction says; the yes names the proposal frames it covers. A correction
revises the proposal and asks again. A no ends it. A yes covers that proposal only; the next change
needs its own.
