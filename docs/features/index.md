---
title: Features
sidebar_label: Features
sidebar_position: 0
---

# Features

The things tokenmeter does, one by name, **newest first**. Every feature has the same three pages: an **overview**, its
**proposal** (the design that was chosen, with its screens) and its **implementation plan**. The decisions behind it
are [ADRs](../adr), and its overview links them.

## Implemented

| Feature                                               | Date | Pages |
| :---------------------------------------------------- | :--- | :---- |
| _None yet._ A feature moves here when its code is in. |      |       |

## In design and build

| Feature                                                                       | Date       | Pages                                                                                                          |
| :---------------------------------------------------------------------------- | :--------- | :------------------------------------------------------------------------------------------------------------- |
| [Problems](./problems/index.md): the app tells what is wrong and offers a fix | 2026-10-30 | [Overview](./problems/index.md), [Proposal](./problems/proposal.md), [Implementation plan](./problems/plan.md) |

## How a feature is written

| Part                    | Answers                                                                                                              | File          |
| :---------------------- | :------------------------------------------------------------------------------------------------------------------- | :------------ |
| **Overview**            | What it is, its date and its status, and links to the other two parts and to its ADRs.                               | `index.md`    |
| **Proposal**            | What it looks like and how it behaves: the chosen design with a screenshot of it, the states and what is still open. | `proposal.md` |
| **Implementation plan** | How it is built: the modules, the data flow with diagrams, the order of commits and the tests.                       | `plan.md`     |

- **The proposal keeps the screenshot.** The design is drawn in a canvas that is deleted once the code is in, so the page,
  with its pictures, is what stays.
- **Order.** A feature's folder is `docs/features/<name>/`. Its `_category_.json` carries a `position` of 99999999
  minus its date as `YYYYMMDD`, so the sidebar lists the newest first without renumbering the others.
- **Status.** A feature is listed under _In design and build_ until its code is in; then its overview says so and it
  moves to _Implemented_, with the date it was implemented.
- Write the ADR before the plan, and the plan before the code.
