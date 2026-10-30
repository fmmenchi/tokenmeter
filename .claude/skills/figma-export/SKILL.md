---
name: figma-export
description: >-
  Puts the current tokenmeter views (widget, Settings, panel) from the SwiftUI code into the Views
  section of the Figma file, or updates the part that a code change touched. Use when Fabio asks to
  export, sync or push the code to Figma, or to build the first copy. Not for designing
  (figma-proposal) and not for applying a design to the code (figma-import).
---

# figma-export

Code to Figma. Answer in Italian, address Fabio as Fabio. No script: map by what each thing **is and
does**, never by layer name or position, and ask where neither side answers. It is `figma-import`
reversed, so it runs only on an **explicit request**: the first copy, or a named change (a commit, a
PR, files). A commit, a rebase or an import is not a request.

## 1. The request and the target

It must name the views or the source change; ask before reading if not. Export the code at branch head,
not at one commit: later commits on the same lines are part of the change. A change that spans several
unrelated views is not one request: ask which to export. If the change came **from** Figma (an import),
there is nothing to export; check that the Views and the `Handoff` frame already say so.

## 2. Who decides

The code decides the value: colours, thresholds' look, fonts, spacing, radii, states, copy. The file
keeps the rest: layout choices, instances, overrides, a pending edit. **Update in place, never redraw or tidy.**
A pending edit on the same field is a conflict: ask, never overwrite. Never copy a value from memory or
from a doc; read it from the source file at the moment you write.

## 3. Procedure

1. **Read the change**: the whole diff and the whole view, per field: before, after, who renders it
   (variants, states). Note what did not move.
2. **Find the owner in Figma**: the frames and components that draw it, by component and variant
   properties. For the first copy there is none: build components first (the bar, the provider block, then
   the views from them), with every state in `docs/use/bars.md`.
3. **Map by role** and sort each difference: code-owned (write), the file's own (leave), conflict or
   missing decision (ask), or a change that would reach more than the request (ask). A runtime value
   (a measured width, an example number) is not exported as a rule.
4. **Ask once**, with your answer for each, before writing anything an open question would change.
5. **Write in place** with `use_figma`, after loading `figma-use`: keep ids, instances and bindings, bind
   variables instead of typing values, swap a variant instead of replacing a node. Capture what a write
   drops (overrides under a swapped node, descriptions) and restore it.
6. **Read back** every changed node and `screenshot` the frames. A read-back that disagrees is not done.

## 4. Never

Write in **Proposals** or **Archive**; detach to make something fit; write a literal over a variable;
re-export everything for one view; delete something still used. The code is not changed by an export.

Report what changed in Figma (node ids, before and after), what did not move, what was asked, and the
Figma link.
