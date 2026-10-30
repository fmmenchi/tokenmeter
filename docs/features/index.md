---
title: Features
sidebar_label: How a feature is written
sidebar_position: 0
---

# Features

A feature is written as a **nucleus** of three parts that belong together, so whoever picks it up finds the whole
thing in one place and nothing is decided twice.

| Part                    | Answers                                                                                                    | Where                                                  |
| :---------------------- | :--------------------------------------------------------------------------------------------------------- | :----------------------------------------------------- |
| **Proposal**            | What it looks like and how it behaves: the design that was chosen, its states and what is still open.      | `proposal.md` in the feature's folder                  |
| **Implementation plan** | How it is built: the modules, the data flow, the order of commits and the tests that show each step works. | `plan.md` in the feature's folder                      |
| **Decisions**           | Why: the structural choices, written before the code.                                                      | the [ADRs](../adr), linked from the feature's overview |

The ADRs keep their place and their numbers, because every ADR links to the others; the feature's overview lists
the ones that belong to it.

## Intent

A design and a plan drift apart when they live in different places. Putting them side by side, with the decisions
they rest on, means a change to one shows up next to the other.

## Adding a feature

1. Make `docs/features/<name>/` with an `index.md` that says what the feature is and lists its three parts.
2. Write the proposal from the design that was chosen (the design itself is drawn in a proposal canvas and deleted when
   it is implemented, so the page is what stays).
3. Write the ADR before the plan, and the plan before the code.
4. Move the status of each part forward as the work does: proposed, accepted, done.

## The features

| Feature                                                                       | Status   |
| :---------------------------------------------------------------------------- | :------- |
| [Problems](./problems/index.md): the app tells what is wrong and offers a fix | proposed |
