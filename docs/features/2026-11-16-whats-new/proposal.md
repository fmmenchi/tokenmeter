---
title: What's new, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# What's new, proposal

The design that was chosen: variant C, a card in the panel, whose button opens the list of variant B. It was drawn as a canvas in
Claude, deleted once the feature is implemented. Only features, never fixes (the author, 2026-11-16).

| Variant | What it was                                                                                    |
| :------ | :--------------------------------------------------------------------------------------------- |
| A       | A wizard window, one page per feature, with a picture and Skip, Back, Next.                    |
| B       | One window listing the new features, newest first, a link to the changelog and Done.           |
| **C**   | **A card at the top of the panel, "3 new features since 0.13.0", Dismiss and See what's new.** |

## What changes

| Surface            | What it shows                                                                                                                                                                                                             |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| The panel          | Under the update notice, a card on the accent at 15%: "3 new features since 0.13.0", the titles in one line, **Dismiss** and **See what's new**.                                                                          |
| The window         | "What's new in tokenmeter": "3 new features since 0.13.0", "You updated from 0.13.0 to 0.15.1. Fixes are in the changelog.", one block per feature (version, title, two lines), **Read the full changelog** and **Done**. |
| Settings › General | **Show what's new again**, beside Show the welcome again.                                                                                                                                                                 |
| The welcome        | Opens on the first launch only, no longer on the first update.                                                                                                                                                            |
| Unchanged          | The update notice before installing, the widget.                                                                                                                                                                          |
