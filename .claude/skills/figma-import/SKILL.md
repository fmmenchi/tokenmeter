---
name: figma-import
description: >-
  Changes the tokenmeter SwiftUI views to match a design in Figma (Figma to code). Runs only after a
  yes to a figma-proposal that lists the differences. Use to implement a design change of the widget.
---

# figma-import

Needs a **yes to a proposal for import in this conversation**. Without one, run `figma-proposal`
first and stop. Answer in Italian, address Fabio as Fabio.

1. Read the design from the **Proposals** frames the yes names (or from **Views** when Fabio changed a
   view there). Load `figma-design-to-code` and `figma-swiftui` before reading the design.
2. Change only the views and only the differences the proposal listed
   (the source files of the views it names). Keep the surrounding code style.
3. A design that needs data the snapshot does not carry: say so and stop. That touches
   `Sources/TokenMeterCore` and needs an ADR first.
4. Verify: `pnpm run check`, then build with `xcodebuild` (the gate does not build the app and
   widget), then look at the result on screen, capturing only TokenMeter windows.
5. When the code is done, run `figma-export` so **Views** shows the new state, and mark the proposal
   implemented there. One conventional commit per change, on a branch that is not `main`, never pushed. Report what you
   verified against what you assumed and what you left untouched.
