---
name: design-proposal
description: >-
  Designs or changes a tokenmeter surface (widget, Settings, menu bar, icon) as a new proposal canvas, after a short
  text proposal and Fabio's yes. Use whenever Fabio asks to design, change, vary or compare anything visual. It
  writes only a new proposal canvas. Not for exporting the code (design-export) nor applying a design (design-import).
---

# design-proposal

You are the designer's agent. Answer in Italian, address Fabio as Fabio. A proposal is **one canvas**, named
`TokenMeter Proposal · <area> · <yyyy-mm-dd>` (the same title in `canvas.json`), holding **all its variants** as artboards, built from a copy of the Views
artboards and from the Design System tokens. You never write in Views, the Design System or the code.

## 1. Read, then propose in text. Do not draw yet

Read the surfaces in scope from the code and the current Views (see `design-export` §1 for how to list the
surfaces: scenes, the widget, icons and assets, not only `: View`). Then write the proposal, ten lines at most:

- the **area** and the general idea, not tied to one case (an alert is "a message and an optional action", not "the
  project warning");
- the **variants**, one line each, and what is the same in all;
- what stays untouched;
- **questions for the code** (data the snapshot lacks, behaviour, a stored choice): never decided here.

Wait for Fabio's yes. A correction revises the proposal. Draw only what he named.

## 2. The four rules

- **A.** Start from a copy of the Views artboards, with every state they have.
- **B.** Use the Design System's tokens and component specs, not loose values. A value Fabio gives becomes the token
  with that role (name it back); if none fits, draw it as a **proposed** token or component and list what it reaches.
- **C.** Keep names: a state that replaces another keeps its name; never delete a state you copied, say in a note that
  it should go.
- **D.** The design decides look, copy and states; the code decides data, behaviour, timing. Approval is Fabio's.

## 3. Making the canvas

Create a `Design` artifact for the proposal (its own link), install the Design System copy, write the variants as
artboards on one page, name each variant. It must be recognisable at a glance in the gallery: the title starts with
"TokenMeter", and a `title1` note "TokenMeter · Proposal · <area>" sits above the first row, with the other notes
to the side so they do not cover it. Do not open or screenshot it unless asked; say so.

## 4. Afterwards

Draft the import request in one sentence for `design-import`; never run it. A proposal has no history: when its code
is in, or it is discarded, offer to delete its canvas; delete it only when Fabio says so, each time.
