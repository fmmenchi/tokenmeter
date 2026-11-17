---
title: Cost in USD, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# Cost in USD, proposal

The design that was chosen, variant A of three. It was drawn as a canvas in Claude, deleted once the feature was implemented.

| Variant | What it was                                                           |
| :------ | :-------------------------------------------------------------------- |
| **A**   | **In the stats only: a cost per model and a total for the range.**    |
| B       | As A, and the cost of each window on its detail line in the panel.    |
| C       | As A, set against the price of the plan, which the app does not know. |

## What changes

| Surface             | What it shows                                                                                                 |
| :------------------ | :------------------------------------------------------------------------------------------------------------ |
| Tokens by model     | A column between the tokens and the share: `≈ $1,050`, or `–` for a model with no price.                      |
| Under the list      | `At API list prices, in this range` and the total, `≈ $1,240`; "the models with a price" when some have none. |
| A closed stats card | Its line ends with the total: `Opus 77% · Sonnet 14% · Fable 9% · ≈ $1,240`.                                  |
| Unchanged           | The panel's quota view, the widget, the shares of tokens.                                                     |
