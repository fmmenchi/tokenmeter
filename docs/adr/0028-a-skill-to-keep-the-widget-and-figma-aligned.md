# ADR 0028 — A skill to keep the widget and Figma aligned

Status: accepted (2026-10-30), reworked the same day from one skill into three

## Context

The widget exists in SwiftUI and nowhere else. Fabio wants it in Figma and wants the two to stay
aligned, in both directions, in the way wishew's skills work: the agent says what it will do and waits
for a yes before it acts. wishew's `issue` skill is a pipeline of subagents, scripts and templates; for
one widget that is far more than the job needs.

## Decision

Three small skills, one file each, in `.claude/skills/` of this repository so they are versioned with the
views they describe. No subagents, no scripts. They are a simplified version of the Figma skills of
Fabio's work repository (a proposal skill, an import skill and a design-system export skill): the same
principles, without its references, record files and design-sync gates.

- **Three sections on the Figma page.** **Views** is what the code looks like now, **Proposals** is what
  could change, **Archive** holds what an import replaced.
- **`figma-proposal`** is the designer's agent. It writes **only in Proposals**, as frames
  `Proposal · <area> · <date>`, starting from a copy of the Views frames. Four rules: design in
  Proposals; build from the code's components and variables; never detach an instance; keep the
  names, and never delete a state. A request that breaks a rule is refused with a route that does not.
  It ends with a drafted request to import, which it never runs.
- **`figma-import`** is the developer's agent. It needs an approved proposal, maps the design to the code
  **by what each thing is** (component and variant, not position or layer name), sorts each difference
  as design-owned, code-owned or a question, asks once, implements, runs the gates (`pnpm run check`
  and `xcodebuild`), then promotes in Figma: replaced frames to Archive, approved frames **copied** into
  Views, a `Handoff` frame. Proposals stays untouched as the record. A need for new data stops it: ADR first.
- **`figma-export`** is code to Figma, on an explicit request only: the first copy, or a named change. It
  writes only in Views, in place, never redraws, asks on a conflicting edit, and reads back and
  screenshots what it wrote.
- **The design decides** composition, spacing, copy, colours and states; **the code decides** data,
  what a state means, timing and example numbers. **Approval is Fabio's.**
- **No fixed list of views**: the skills find them in the source.
- The Figma work is done with the Figma skills already installed (`figma-use`, `figma-design-to-code`...).

## Consequences

- A change to a view that is not mirrored in Figma is found the next time the skill runs, not
  continuously. There is no automatic sync.
- The skill lives under `.claude/`, which is Claude Code specific; other agents do not see it. The
  tool-neutral rules stay in `AGENTS.md`.
- It is unverified until it has been run against a real Figma file.
