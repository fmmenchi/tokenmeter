# ADR 0009 — Design lives in artifacts, and the flow goes one way

Status: accepted (2026-10-30, consolidated 2026-11-02; the first design, a Figma file kept aligned by a skill, was replaced)

## Context

On a Starter plan Figma's MCP server allows 20 calls a month, and one session used them up before the first proposal was looked at.
Claude Design moves into Claude as a `Design` artifact (a canvas of live artboards) and a `Design System` artifact, with no per-call cap.

## Decision

The design lives in artifacts, and the flow is one way: **code → design system → Views → proposals → (approved) → code.**

- **The Design System** holds the tokens and components, read from the code, never from memory; a value the code leaves to the system is
  marked as such.
- **Views** is one `Design` canvas holding every view as the app looks now, built from the design system.
- **A proposal is one canvas**, named `TokenMeter Proposal · <area> · <yyyy-mm-dd>`, started from a copy of the Views artboards, and
  temporary: once its code is in and Views has been refreshed, or when it is discarded, its canvas is deleted, only when Fabio asks, each
  time. What stays is the feature's proposal page with its screenshot.
- **Three skills:** `design-proposal` writes a new proposal canvas only, after a text proposal; `design-export` writes the design system
  and Views from the code, on an explicit request, in place; `design-import` maps an approved proposal to the code by role
  (`data-component` and `data-state` carry the SwiftUI type and state), asks once, implements, runs the gates and then the export.

## Consequences

- An artboard is HTML, not component instances: identity is a convention, and a variable is a CSS custom property.
- A design system installed in a canvas is a copy that changes only when reinstalled. Artifacts are private; sharing is Fabio's.
- Not verified: how the `Design System` type holds components that are not React.
