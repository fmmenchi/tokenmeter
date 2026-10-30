# ADR 0028 — A skill to keep the widget and Figma aligned

Status: accepted (2026-10-30)

## Context

The widget exists in SwiftUI and nowhere else. Fabio wants it in Figma and wants the two to stay
aligned, in both directions, in the way wishew's skills work: the agent says what it will do and waits
for a yes before it acts. wishew's `issue` skill is a pipeline of subagents, scripts and templates; for
one widget that is far more than the job needs.

## Decision

One skill, one file: `.claude/skills/widget-figma/SKILL.md` in this repository, so it is versioned with
the views it describes. No subagents, no scripts.

- **Proposal first.** The skill reads the SwiftUI views and, if a Figma file is named, the Figma file,
  then writes a short proposal: which direction, what will be created or changed, what will not be
  touched. It acts only after Fabio says yes; a "no" or a correction ends it or revises the proposal.
- **Both directions.** Code to Figma: build the widget, the panel's `ProviderBlock` and their states in
  Figma. Figma to code: change the SwiftUI views to match a design change, listing each difference
  before editing.
- **The code is the source.** When the two disagree and nobody says otherwise, the proposal treats
  `Shared/UsageViews.swift` and the widget as right and Figma as the copy. Values (colours,
  thresholds, spacing) are read from the code, never copied into the skill, so the skill cannot go stale.
- The Figma work itself is delegated to the Figma skills already installed (`figma-use`,
  `figma-generate-design`, `figma-swiftui`); this one only says what to build and in what order.

## Consequences

- A change to a view that is not mirrored in Figma is found the next time the skill runs, not
  continuously. There is no automatic sync.
- The skill lives under `.claude/`, which is Claude Code specific; other agents do not see it. The
  tool-neutral rules stay in `AGENTS.md`.
- It is unverified until it has been run against a real Figma file.
