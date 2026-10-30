---
name: figma-import
description: >-
  Brings an approved Figma proposal into the tokenmeter SwiftUI views: maps the design to the code by
  what each thing is, applies the design's part, asks about the rest, then promotes the proposal in
  Figma. Use when Fabio asks to import, apply or implement something from Figma. Not for designing
  (figma-proposal).
---

# figma-import

You are the developer's agent. Answer in Italian, address Fabio as Fabio. There is no script: read the
design and the code, map one to the other by what each thing **is and does**, change the code that owns it,
and ask where neither side answers. A rename or a reordering in Figma must cost a moment of judgement,
not the import.

## 1. The request

Do not read anything before you have it: **which proposal** (`Proposal · <area> · <date>` or a link
to its frames) and **which view** it changes. Confirm Fabio approved it; only approved work goes in. If
a piece is missing, that is the one question to ask first.

## 2. Who decides

The design decides composition, spacing, copy, colours, which states exist and what each shows. The code
decides the data a view receives, what a state or threshold means, timing, and every example number
(a fixture, not a rule, until Fabio says so). You decide neither: a difference you cannot attribute
to one of them is a question.

## 3. The bridge is the components and variables

A design node finds its code owner by **what it is built from** and its **variant properties**, not by
position or layer name: the bar and the provider block in Figma are `ProviderBlock` and the bar in
`Shared/UsageViews.swift`; a variable bound to a colour or spacing is the constant the code reads. Two nodes
with the same component and role are the same thing wherever they sit. A node drawn by hand where a
component exists, or detached, is a question with the candidates named, not a guess.

## 4. Procedure

1. **Read the design**: a screenshot of the frames, the tree with each node's component and
   variant properties, the characters for the copy, the bound variables. Read every state provided
   and note which states the current view has that the proposal does not.
2. **Find the code owner**: the view that renders it (`grep -rln ": View" App Widget Shared`), read whole.
3. **Map by role**: walk the SwiftUI top to bottom; for each element find the node that does that job. Note
   what differs (value, colour, variant, copy, order). What the design has and the code does not is an
   **addition**; the opposite is a **removal**, and a removed state is confirmed, never assumed.
4. **Sort each difference**: design-owned (apply), code-owned (keep and say so), or a question.
   A change to `Sources/TokenMeterCore` or the snapshot is not a visual change: stop, it needs an ADR.
5. **Ask once**: one message with every question, each with the answer you would give. No edit while an
   open question would change it.
6. **Implement**: change the owner using the components the design uses; keep the surrounding style;
   a behaviour that changed gets a test.
7. **Gates**: `pnpm run check`, then `xcodebuild` for the app and widget (the gate does not build them),
   then look at the result on screen, capturing only TokenMeter windows. Say plainly if it was not seen.
8. **Promote in Figma**: only now. Move the replaced Views frames to **Archive** as `<name> before
<change> · <date>`; **copy** (never move) the approved frames into Views with the canonical names; leave a
   text frame `Handoff · <date>` naming the proposal. The proposal frames stay untouched: they are the record.

## 5. Record and rules

The commit message carries the request, the role map (what changed, how it was sorted), the questions
and answers, and what stays with the code. One conventional commit per change, never on `main`, never
pushed. Never invent a design decision, never treat "same slot" as "same thing", never import a
difference you cannot attribute to a role, and never write in Proposals.
