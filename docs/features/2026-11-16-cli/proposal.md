---
title: Command-line tool, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# Command-line tool, proposal

Approved in text on 2026-11-16; nothing visual to draw but one line in Settings.

| Command                                                     | Prints                                                                                          |
| :---------------------------------------------------------- | :---------------------------------------------------------------------------------------------- |
| `tokenmeter`                                                | One line a window: `Claude · 5 hours   72% left   resets in 2h 9m`, then the age of the reading |
| `tokenmeter --json`                                         | The same as JSON, `"version": 1`                                                                |
| `tokenmeter stats [--range month\|quarter\|year\|lifetime]` | The verdict, the windows' summaries, the tokens by model and the cost at API list prices        |
| `--left`, `--used`                                          | Override the reading chosen in the app                                                          |
| `--help`, `--version`                                       | What it says                                                                                    |

Exit codes: 0 a fresh reading, 1 no snapshot (the app never ran), 2 a reading older than 10 minutes.

Settings › General gains a row "Command-line tool" with the path of the tool in the bundle and a button **Copy install command**,
which copies `ln -sf '<path>' /usr/local/bin/tokenmeter`.

Untouched: the panel, the widget, `tokenmeter-probe`. A short format for Claude Code's status line is left for later.
