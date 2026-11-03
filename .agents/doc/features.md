# Features — agent rules

A feature is a **nucleus**: a proposal, an implementation plan and the ADRs behind them, in one place. The full pattern,
with its diagram, is in `docs/features/index.md`, and the step-by-step with the commands in
`docs/develop/implement-a-feature.md`; this page is what an agent does and does not do.

Read this when asked to design, propose or build something new, or when touching a feature's docs.

## Where things go

| What                                   | Where                                                                                                                                                                    |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| The feature's folder                   | `docs/features/<yyyy-mm-dd>-<name>/`                                                                                                                                     |
| Overview (date, status, links, intent) | `index.md` in it                                                                                                                                                         |
| The chosen design, with screenshots    | `proposal.md` and `proposal-*.png` in it                                                                                                                                 |
| How it is built, with diagrams         | `plan.md` in it                                                                                                                                                          |
| Sidebar label and order                | `_category_.json` in it: `label` is the feature's **title**, `position` is 99999999 minus the date as `YYYYMMDD`, less 1 for each feature of the same day built after it |
| The list of features                   | `docs/features/index.md`, newest first; a feature is under _In design and build_ until its code is in                                                                    |
| The decisions                          | `docs/adr/NNNN-…`, linked from the overview                                                                                                                              |

The label is the feature's title in the user's words, never the name of a concept in the code.

## Order of work

1. **Describe it.** Use the `design-proposal` skill: a text proposal of ten lines, then wait for Fabio's yes. Draw nothing
   before it.
2. **Design it.** The proposal is one canvas, `TokenMeter Proposal · <area> · <yyyy-mm-dd>`, with all its variants, from a
   copy of the Views and the Design System's tokens.
3. **Wait for Fabio to approve the design.** Delete the other variants only when he asks, each time; it is permanent. No
   history of proposals is kept. Then write the feature's folder from the chosen design: `index.md` (status: in design) and
   `proposal.md` with a screenshot.
4. **Write the technical plan.** ADR before the plan, plan before the code: status `proposed`. Every plan ends with the
   reconciliation (item 9) written as its own row: it is never left implied.
5. **Wait for Fabio to approve the plan.** The ADR is `accepted` when he confirms. No code before.
6. **Build it** with the `design-import` skill, one commit per step of the plan, three files at most, the gate green.
   `pnpm run check` does not build the app or the widget: also run `xcodebuild`. Update the Use and Develop pages with the
   code, in the same branch.
7. **Review and preview.** Read the diff against the ADR and the plan, then `./scripts/preview.sh` builds the branch and
   opens it without installing it. Report what was not seen as not seen: the widget needs the install, and a tooltip only
   shows on the real app.
8. **Merge** the branch into `main` with `git merge --no-ff`, a merge commit, and run the gate on `main`. Never push.
9. **Reconcile the interface**, on a short `docs/` branch once the code is in `main`: run `design-export` so the Views and the
   Design System match the code as built, set the status, move the row to _Implemented_ with its date, and offer to delete
   the proposal canvas.

## Screenshots of a proposal

The canvas cannot be captured from the terminal, so render the artboards from their files:

- put the `.dc.html` files, the design system's `tokens.css` (at `ds/tokenmeter/tokens.css`) and a small page that frames
  each artboard in an `<iframe>` of its own size in one folder;
- screenshot the page with headless Chrome: `--headless=new --hide-scrollbars --force-device-scale-factor=2
--window-size=<w>,<h> --screenshot=<file>`; set each iframe's height to its content so there is no empty space;
- save as `proposal-<what>.png` in the feature's folder and put it in `proposal.md` with a descriptive alt text.

Show only tokenmeter's own windows, with sample data from the docs, never real usage.

## Do not

- Write code for a feature before its ADR and its plan exist.
- Put a link to a canvas in the docs: canvases are private and temporary. Write the design into `proposal.md`.
- Name a feature folder after a code concept, or renumber the other features to make room: the `position` rule orders
  them.
- Edit another feature's folder while working on one.
