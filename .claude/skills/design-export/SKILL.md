---
name: design-export
description: >-
  Puts the tokenmeter app's current look into its design artifacts: the Design System (tokens, rules,
  component specs, icons) and the Views canvas, read from the SwiftUI code. Use when Fabio asks to export,
  sync or build the first copy of the design, or to refresh it after a code change. Not for designing
  (design-proposal) and not for applying a design to the code (design-import).
---

# design-export

Code to design. Answer in Italian, address Fabio as Fabio. The code decides every value: read it from the source at
the moment you write, never from memory or from a doc. Runs only on an **explicit request**: the first copy, or a
named change. A commit or an import is not a request.

## 1. Inventory first, from the code, and ask

Before writing anything, list the **surfaces** the app has, from the places that declare them, not only from
`: View`:

- `App/TokenMeter/TokenMeterApp.swift`: every `Scene` (the `MenuBarExtra` with its **label and icon**, each
  `Window`), and what each one shows;
- `Widget/`: the widget and its families;
- icons and images: `App/TokenMeter/Assets.xcassets` (the app icon) and `MenuBarIcon.swift` (drawn in code);
- the shared views they use (`Shared/`), and the state each one can be in.

Show the list and ask which are **in scope**. Do exactly those: no surface, state or variant Fabio did not name,
and none missing from what he named. (A first export once added a panel and extra variants nobody asked for and
missed the app icon and the menu-bar item, because only `: View` was searched.)

## 2. Where it goes, and one source per thing

- **Design System** (artifact type `Design System`): tokens (`tokens.json` as lists, plus the first
  `tokens.css` written by hand, compiled as the type says), the README (usage rules that name tokens), one card
  per component (README and a static preview), icons as assets. It owns **values and rules**.
- **Views** (one `Design` canvas, page `Views`): one artboard per surface in scope, built from the tokens as CSS
  custom properties. It owns **screens**. Mark elements with `data-component` and `data-state` = the SwiftUI type
  and state, so an import can map by role.
- A value lives in the tokens only. A component's look lives in the Design System card; a screen does not copy a
  value, it uses the token. Mark a value the code leaves to the system (system colours, text sizes) as
  **assumed**; never present it as read from the code.

## 3. Writing

Follow the type's own instructions when you create or revise (index first, then files; a Design System copy
into the canvas with its record; images as uploads). Update in place, never redraw. A change Fabio made on the page
since you last read it is a conflict: read it and ask. Do not open or screenshot the result unless asked; say what you
did not check.

## 4. Report

What you exported (which surfaces), what is assumed, what you did not read, and the links. One conventional commit if
the repository changed; the artifacts are not in the repository.
