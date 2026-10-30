# ADR 0028 — A skill to keep the widget and Figma aligned

Status: accepted (2026-10-30), reworked the same day from one skill into three

## Context

The widget exists in SwiftUI and nowhere else. Fabio wants it in Figma and wants the two to stay
aligned, in both directions, in the way wishew's skills work: the agent says what it will do and waits
for a yes before it acts. wishew's `issue` skill is a pipeline of subagents, scripts and templates; for
one widget that is far more than the job needs.

## Decision

Three small skills, one file each, in `.claude/skills/` of this repository so they are versioned with
the views they describe. No subagents, no scripts.

- **`figma-proposal`** reads the SwiftUI views, the states in the docs and, if a Figma link is given,
  the Figma file. It writes a proposal of ten lines at most (direction, what is created or changed, what
  is not touched, differences, what is unknown) and **waits for a yes**. A correction revises it, a no
  ends it, and a yes covers that proposal only.
- **`figma-export`** (code to Figma) builds the views the proposal names and their states in Figma. It runs only
  after a yes, and takes every value from the code at that moment, never from a copy.
- **`figma-import`** (Figma to code) changes the SwiftUI views for the differences the proposal listed.
  A design that needs data the snapshot lacks stops there: it needs an ADR.
- **Two sections in the Figma file.** **Views** is what the code looks like now, written only by
  `figma-export`. **Proposals** is what could change, written only by `figma-proposal`, additive, one set
  of frames per proposal. An implemented proposal is exported to Views and marked `✓` in Proposals.
- **No fixed list of views.** There are the widget, Settings and the panel today and there will be more, so
  `figma-proposal` finds the views in the source and says which it takes in scope and which it leaves.
- The code is the source: when the two disagree and nobody says otherwise, Figma is the copy.
- The Figma work itself is done with the Figma skills already installed (`figma-use`,
  `figma-generate-design`, `figma-swiftui`, `figma-design-to-code`).

## Consequences

- A change to a view that is not mirrored in Figma is found the next time the skill runs, not
  continuously. There is no automatic sync.
- The skill lives under `.claude/`, which is Claude Code specific; other agents do not see it. The
  tool-neutral rules stay in `AGENTS.md`.
- It is unverified until it has been run against a real Figma file.
