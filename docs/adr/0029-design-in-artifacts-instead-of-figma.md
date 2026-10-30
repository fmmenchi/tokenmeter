# ADR 0029 — Design in artifacts instead of Figma

Status: accepted (2026-10-30); supersedes [ADR 0028](./0028-a-skill-to-keep-the-widget-and-figma-aligned.md)

## Context

[ADR 0028](./0028-a-skill-to-keep-the-widget-and-figma-aligned.md) put the design in a Figma file, written
through Figma's MCP server. On Fabio's Starter plan that server allows 20 calls a month to his seat; one
session built the first copy and the first proposal and used them up, before the proposal was ever looked
at. A paid seat would lift the limit, at a cost for one person's occasional use.

Claude Design, the standalone site, closes on 14 December 2026 and moves into Claude: a `Design` artifact
(a canvas of live artboards) and a `Design System` artifact, both made with the Artifact tool, with no
per-call cap of their own.

## Decision

The design lives in artifacts, in three kinds, and the flow goes one way:
**code → design system → Views → Proposals → (approved) → code.**

- **Design system** (a `Design System` artifact): the tokens and components, read from the code, never
  from memory. A value the code does not state (the system colours, for example) is marked as such.
- **Views** (one `Design` canvas, page `Views`, holding every view): what the app looks like now, built from the
  design system. Each view is an artboard of that one canvas; the tool keeps each artboard in its own file inside it.
- **One canvas per proposal**, named `Proposal · <area> · <yyyy-mm-dd>`, started from a copy of the Views
  artboards. An approved proposal is not edited: a further change is a new canvas copied from it.
- **A proposal is temporary.** Once its code is in and Views has been refreshed from the code, or when it is
  discarded, its canvas is deleted. Deleting is permanent and breaks the link, so it happens only when Fabio
  asks, each time. No history of proposals is kept, by choice.

Three skills replace the three of ADR 0028, with the same rules:

- **`design-proposal`** writes a new proposal canvas only, after a text proposal and the same four rules
  (build from the design system, no hand-written values, keep the canonical names, never delete a state).
  Approval is Fabio's.
- **`design-export`** writes the design system and Views, on an explicit request only, in place, reading
  the code at that moment.
- **`design-import`** reads an approved proposal, maps it to the code **by role** (`data-component` and
  `data-state` carry the SwiftUI type and state), asks once, implements, runs the gates, then runs the export so
  Views matches the code again, and offers to delete the proposal canvas.

The Figma file stays as it is, a frozen archive; its three skills are removed when these exist.

## Consequences

- No cap on calls, but the work counts against Fabio's Claude usage (third-party reports, not confirmed).
- An artboard is HTML, not component instances: identity is a convention (`data-component`), not enforced
  by the tool, and a variable is a CSS custom property, not a bound variable.
- A design system installed in a canvas is a copy; it changes only when reinstalled.
- Artifacts are private; sharing is Fabio's to do from the page.
- Not verified: how the `Design System` type holds components that are not React, and whether an earlier
  version of an artifact can be restored from the page.
