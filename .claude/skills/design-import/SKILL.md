---
name: design-import
description: >-
  Brings an approved tokenmeter proposal canvas into the SwiftUI code: maps the design to the code by what each thing
  is, applies the design's part, asks about the rest, then refreshes the Views. Use when Fabio asks to import, apply or
  implement a proposal. Not for designing (design-proposal).
---

# design-import

You are the developer's agent. Answer in Italian, address Fabio as Fabio. No script: map the design to the code by
what each thing **is and does**, change the code that owns it, ask where neither side answers.

## 1. The request

Do not read anything before you have it: **which proposal canvas**, **which variant**, **which surface**. Confirm
Fabio approved it. Missing piece: that is the one question to ask first.

## 2. Who decides

The design decides look, copy, colours, which states exist. The code decides the data a surface receives, what a state or
threshold means, timing, example numbers. You decide neither: a difference you cannot attribute to one of them is a
question. A need for new data (a snapshot field, a stored choice) is not a visual change: stop, it needs an ADR.

## 3. By role, not by position

Elements carry `data-component` and `data-state` = the SwiftUI type and state (`ProviderBlock`, `WindowRow`,
`QuotaBar`). A node finds its code owner by those and by the tokens it uses, not by its place or its markup. A node with
none, or a hand-written copy of a component, is a question with the candidates named.

## 4. Procedure

1. Read the proposal's artboards (files, tokens used, copy, every state) and note the states the surface has now that
   the proposal lacks.
2. Find the owner: the scene or view that renders the surface (`TokenMeterApp.swift`, `Widget/`, `Shared/`,
   `App/TokenMeter/`), read whole.
3. Map by role; list additions and removals. A removed state is confirmed, never assumed.
4. Sort each difference: design-owned (apply), code-owned (keep, say so), or a question.
5. Ask once: every question with the answer you would give. No edit while an open question would change it.
6. Implement with the same components; keep the surrounding style; a changed behaviour gets a test.
7. Gates: `pnpm run check`, then `xcodebuild` for app and widget (the gate does not build them), then look at the
   result on screen (only TokenMeter windows). Say plainly if it was not seen.
8. Run `design-export` for the surfaces touched, so Views matches the code, and offer to delete the proposal canvas.

## 5. Record and rules

The commit message carries the request, the role map, the questions and answers. One conventional commit per change,
never on `main`, never pushed. Never invent a design decision, never treat "same place" as "same thing".
