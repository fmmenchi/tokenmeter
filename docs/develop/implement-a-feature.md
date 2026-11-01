---
title: Implement a Feature
sidebar_label: Implement a Feature
sidebar_position: 6.5
---

# Implement a Feature

How to take a feature from an idea to code that is in and documented, step by step. The shape of the work, and why it
is the same every time, is in [Features](../features/index.md); this page is what to do and what to run.

## Intent

A feature is written as a nucleus of three parts kept in one folder: its **proposal**, its **implementation plan** and
the **ADRs** behind it. The order is fixed: description, design, approval, technical plan, approval, build, review and
preview, merge, and the reconciliation of the interface. Nothing is built before the design and the plan are approved.

## Before you start

- A semantic branch, never `main`: `feat/<name>` or `docs/<name>`. The pre-push hook checks it.
- The gate is `pnpm run check`. It does not build the app or the widget, so changes there also need `xcodebuild`
  (step 6), and the branch is tried with `./scripts/preview.sh` (step 7).
- The skills are in `.claude/skills/`: `feature` runs the whole flow and stops at each approval, and it calls
  `design-proposal`, `design-import` and `design-export` at their steps.

## Step 1: Describe the feature

Describe the feature in a short text proposal (ten lines at most): what it is, the variants if there are several, what
it leaves untouched and the questions for the code. `design-proposal` writes it and waits for a yes. Nothing is drawn
yet.

## Step 2: Design it

With the yes, `design-proposal` draws the variants in one canvas named `TokenMeter Proposal · <area> · <yyyy-mm-dd>`,
from a copy of the Views and with the tokens of the Design System, not loose values. A new element is drawn as a proposed
component.

## Step 3: Approve the design

You choose the variant. The other variants are deleted only when you ask: it is permanent. Then the feature's folder is
written from the chosen design.

Make `docs/features/<yyyy-mm-dd>-<name>/` with three files and a category file:

| File              | Holds                                                                                                        |
| :---------------- | :----------------------------------------------------------------------------------------------------------- |
| `index.md`        | the feature's title, its date and status (in design), what it is, and links to the other two and to the ADRs |
| `proposal.md`     | the chosen design in words, its states and what is open, with a screenshot of it                             |
| `_category_.json` | `label` is the feature's **title**, `position` is 99999999 minus the date as `YYYYMMDD`                      |

Add a row to [Features](../features/index.md) under _In design and build_.

The canvas is deleted once the code is in, so the screenshot is what stays. The canvas cannot be captured from the
terminal, so render the artboards from their files: one page with each artboard in an `<iframe>` of its own size, the
design system's `tokens.css` beside it, and headless Chrome:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --hide-scrollbars \
  --force-device-scale-factor=2 --window-size=900,750 --screenshot=proposal-overview.png file://$PWD/overview.html
```

Set each iframe's height to its content so there is no empty space, save the image beside `proposal.md` and give it
a descriptive alt text. Show only tokenmeter's own windows, with the sample data of the docs.

## Step 4: Write the technical plan

A structural choice gets `docs/adr/NNNN-title.md` before any code: status, context, decision, consequences, and what
is still open. It is `proposed` until you confirm it, then `accepted`. The feature's overview links it.

`plan.md` in the feature's folder says how it is built:

- the pieces and how the data flows, as [Mermaid](https://mermaid.js.org) diagrams;
- the files each piece adds, and where they go ([Architecture](./architecture.md));
- the **order of commits**, one concern each and three files at most, and the tests that show each step works.

A step whose point is not testable is split until it is.

## Step 5: Approve the plan

The ADR becomes `accepted` when you confirm it, and the plan is yours to approve too. Nothing is built before both.

## Step 6: Build it

One commit per step of the plan, conventional, each leaving the gate green:

```bash
pnpm run check                      # prettier, swift test, helper scripts, docs build
xcodegen generate -q                # only if project.yml changed
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Debug \
  -derivedDataPath .build/xc build  # the app and the widget, which the gate does not build
```

`design-import` brings a chosen proposal into the code by what each thing is, asks once about what the design cannot
decide, and runs these gates. The Use and Develop pages the feature changes are updated with the code, in the same
branch.

## Step 7: Review and preview

- **Review** the diff against the ADR and the plan: one concern per commit, three files at most, nothing the plan does not
  name.
- **Preview** the branch without installing it: `./scripts/preview.sh` builds it, quits the TokenMeter that is running and
  opens the build, with your own data. Look at the menu bar, the panel and Settings. The widget needs
  [the install](./build-and-run.md#step-4-install-it-and-let-it-start-at-login).
- A visual change that was not seen is reported as not seen. A defect found here is fixed on the branch.

## Step 8: Merge

Merge the finished branch into `main` with a merge commit, never a fast-forward and never a rebase:

```bash
git checkout main
git merge --no-ff <branch>
```

Run the gate on `main`. Pushing is yours.

## Step 9: Reconcile the interface

On a short `docs/` branch, once the code is in `main`:

1. Run `design-export` so the Views and the Design System match the code as built, and delete the proposal canvas when you
   are sure.
2. Set the feature's status to implemented, move its row to _Implemented_ with the date, and set the ADR to `accepted` if
   it is not yet.

## Checklist

| Done                                                       | Where          |
| :--------------------------------------------------------- | :------------- |
| The proposal, with a screenshot, approved                  | `proposal.md`  |
| The ADR, accepted, and the plan, approved                  | `docs/adr/`    |
| The code, one commit per step, gate and `xcodebuild` green | the repository |
| The branch reviewed and previewed                          | your Mac       |
| The branch merged into `main` with a merge commit          | the repository |
| The Views and Design System reconciled, the status set     | `docs/`        |

## Related

- [Features](../features/index.md): the pattern and the list
- [Contribute](./contribute.md): branches, commits and the gate
- [Architecture](./architecture.md): where a file goes
