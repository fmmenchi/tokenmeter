---
name: tokenmeter-figma-export
description: >-
  Builds the tokenmeter views the proposal names (the widget, Settings, the panel) in Figma from the SwiftUI views (code to Figma).
  Runs only after a yes to a tokenmeter-figma-proposal. Use to put the widget on Figma or refresh a Figma copy.
---

# tokenmeter-figma-export

Needs a **yes to a proposal for export in this conversation**. Without one, run `tokenmeter-figma-proposal`
first and stop. Answer in Italian, address Fabio as Fabio.

1. Load the installed Figma skills: `figma-use` before any `use_figma` call, then
   `figma-generate-design`, and `figma-swiftui` for the SwiftUI side.
2. Take **every value from the code at this moment**: colour thresholds and tints, fonts, spacing,
   radii, the bar's shape, from the source files of the views in the proposal. Never from memory, never from another skill or
   a doc, which can be stale.
3. Write into the **Views** section only (create it if missing); never into **Proposals**. Update a view's
   frames in place instead of adding a duplicate. A proposal that has been implemented in code and then
   exported here is renamed `✓ ` + its name in **Proposals** and left there as history.
4. Build components first (the bar, the provider block), then the frames from them, one set per view in the proposal, each in the states the proposal listed. Work in the new page or file the proposal
   named; never edit frames it did not name.
5. Verify: a screenshot of each frame against the states listed. Report what you checked against what
   you assumed, what you left untouched, and the Figma link.
