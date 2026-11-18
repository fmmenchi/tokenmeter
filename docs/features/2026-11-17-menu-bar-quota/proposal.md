---
title: Quota in the menu bar, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# Quota in the menu bar, proposal

The design that was chosen: variant D, a figure per provider in the order of the panel, named by a tooltip. It was drawn as a
canvas in Claude, which is deleted once the feature is implemented; this page is what stays.

![The menu bar in light and dark: the gauge followed by the figures 31% and 99%, then the same with the order swapped, a stale figure with a tilde, a dash in place of a missing figure, a running-low figure in plain text and in red, the gauge with its dot, a crowded bar with one figure, and three tooltips that name each figure](./proposal-menu-bar.png)

| Variant | What it was                                                                                           |
| :------ | :---------------------------------------------------------------------------------------------------- |
| A       | One figure: the tightest window of every provider and account.                                        |
| B       | A figure per provider with a letter, C and G; dropped because Claude and Codex are both C.            |
| C       | The gauge's arc is the quota, and a figure appears only when running low.                             |
| **D**   | **A figure per provider, in the order of the panel's cards, no logos; a tooltip names every figure.** |

## What changes

| Surface     | What it shows                                                                                                                           |
| :---------- | :-------------------------------------------------------------------------------------------------------------------------------------- |
| Menu bar    | The gauge, then one figure per provider, in the order of its cards in the panel, each its tightest window, Left or Used as in Settings. |
| The tooltip | One for the whole item, every figure named in the same order: "Claude 31% left · ChatGPT 99% left". The same text is read by VoiceOver. |
| Unchanged   | The gauge and its dot, the panel, the notices, the widget, the app icon.                                                                |

## Rules

- **The place says the provider.** The figures follow the order of the cards, which the user sets; a card hidden from the
  panel is hidden here too.
- **A place is never given away.** A provider with no figure yet shows "–" in its place, so the next figure never slides into
  it.
- **The same signs as the panel.** "~" before a reading older than 10 minutes; the tooltip says it in words, "read 25 minutes
  ago".
- **Running low** is under 30% left, as in the notices. The figure is plain text by default; red, with the proposed token
  `menubar-figure-low` (= `quota-low`), is drawn as the alternative.
- **A crowded bar** shows one figure, the tightest of all, as variant A; the tooltip gives it its name, "the tightest".
- **No logos.** Anthropic's trademark guidelines allow its marks only in materials it approves beforehand and forbid changing
  their colour, so a monochrome Claude mark is not possible; one brand's logo alone would not help, and a mark of our own
  would have to look like neither brand.

## Questions for the code

- Which window is "the tightest" of a provider: do model limits and windows with no figure count?
- With several accounts of one provider: one figure per provider, at the place of its first card, or one per card?
- Is the figure a choice in Settings, and is it off at first?
- How often it redraws, and how a crowded bar is detected.
- Does `MenuBarExtra` show a tooltip set with `.help()` on its label, or does it need the status item's button?
- The Design System says the menu-bar item carries no percentage: that rule changes with this feature.

The tooltip's look is the system's; the picture draws it with the Design System's tokens, and the phrase "read 25 minutes ago"
is new copy. The picture was rendered from the canvas's drawing, not captured from a real menu bar.
