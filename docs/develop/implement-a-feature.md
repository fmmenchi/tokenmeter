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
the **ADRs** behind it. The order is fixed: proposal, ADR, plan, code. Nothing is built before the decision and the
plan are written.

## Before you start

- A semantic branch, never `main`: `feat/<name>` or `docs/<name>`. The pre-push hook checks it.
- The gate is `pnpm run check`. It does not build the app or the widget, so changes there also need `xcodebuild`
  (step 5).
- The three design skills are in `.claude/skills/`: `design-proposal`, `design-import` and `design-export`.

## Step 1: Propose

Describe the feature in a short text proposal (ten lines at most): what it is, the variants if there are several, what
it leaves untouched and the questions for the code. `design-proposal` writes it, waits for a yes and then draws the
variants in one canvas named `TokenMeter Proposal · <area> · <yyyy-mm-dd>`. Choose the variant, and delete the others
when you are sure: it is permanent.

## Step 2: Write the feature's folder

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

## Step 3: Write the ADR

A structural choice gets `docs/adr/NNNN-title.md` before any code: status, context, decision, consequences, and what
is still open. It is `proposed` until you confirm it, then `accepted`. The feature's overview links it.

## Step 4: Write the plan

`plan.md` in the feature's folder says how it is built:

- the pieces and how the data flows, as [Mermaid](https://mermaid.js.org) diagrams;
- the files each piece adds, and where they go ([Architecture](./architecture.md));
- the **order of commits**, one concern each and three files at most, and the tests that show each step works.

A step whose point is not testable is split until it is.

## Step 5: Build it

One commit per step of the plan, conventional, each leaving the gate green:

```bash
pnpm run check                      # prettier, swift test, helper scripts, docs build
xcodegen generate -q                # only if project.yml changed
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Debug \
  -derivedDataPath .build/xc build  # the app and the widget, which the gate does not build
```

`design-import` brings a chosen proposal into the code by what each thing is, asks once about what the design cannot
decide, and runs these gates. Then look at the result on screen: the menu bar, the panel, the widget, Settings. A visual
change that was not seen is reported as not seen.

## Step 6: Finish

1. Run `design-export` so the design artifacts match the code, and delete the proposal canvas when you are sure.
2. Set the feature's status to implemented, move its row to _Implemented_ with the date, and set the ADR to `accepted`.
3. Update the [Use](../use/what-it-does.md) pages the feature changes, and the Develop pages (Architecture, Core API,
   Commands and Files) that describe what moved.

## Checklist

| Done                                                       | Where          |
| :--------------------------------------------------------- | :------------- |
| The proposal, with a screenshot                            | `proposal.md`  |
| The ADR, accepted                                          | `docs/adr/`    |
| The plan, with its order of commits                        | `plan.md`      |
| The code, one commit per step, gate and `xcodebuild` green | the repository |
| The status, the row in the list, the Use and Develop pages | `docs/`        |

## Related

- [Features](../features/index.md): the pattern and the list
- [Contribute](./contribute.md): branches, commits and the gate
- [Architecture](./architecture.md): where a file goes
