# ADR 0032 — A features section groups proposal, plan and decisions

Status: accepted (2026-10-30); extends [ADR 0022](./0022-docs-split-by-reader.md)

## Context

[ADR 0022](./0022-docs-split-by-reader.md) split the docs into Use, Develop and Decisions. A feature that is designed and
then built has three kinds of writing that drift apart when they live in different places: what it looks like and does
(the design), how it is built, and why. The design was drawn in a canvas that is deleted once the code is in, so nothing
durable said what had been chosen.

## Decision

A fourth section, **Features** (`docs/features/`), with one folder per feature. A feature is a **nucleus** of three
parts:

- a **proposal** (`proposal.md`): the design that was chosen, its behaviour and states and what is still open, written
  so it survives the deletion of the canvas it came from;
- an **implementation plan** (`plan.md`): the modules, the data flow, the order of commits and the tests, with diagrams;
- the **decisions**: the ADRs. They keep their place in `docs/adr/` and their numbers, because every ADR links to the
  others; the feature's `index.md` lists the ones that belong to it.

`docs/features/index.md` says how a feature is written. The first feature is Problems, whose plan moved here from
`develop/`. The word "design" in the section means the proposal, not a separate document.

## Consequences

- A change to one part shows up next to the other two.
- A page belongs to one feature, and a feature to this section; the Develop pages stay about the app as it is.
- The Overview lists the section, and `docs/develop/contribute.md` points to it.
- Public URLs for the plan change (it was added hours before and linked from nowhere else).
