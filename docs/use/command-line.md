---
title: Command line
sidebar_label: Command line
sidebar_position: 8.7
---

# Command line

tokenmeter has a command, `tokenmeter`, that prints in Terminal what the app shows: the quota, and with `stats` the suggestion, the
windows, the tokens by model and their cost. It is inside the app and updates with it.

## Put it on your PATH

In Settings › General, **Copy install command**, then paste it in Terminal. It links `/usr/local/bin/tokenmeter` to the command inside
the app; macOS asks for your password because `/usr/local/bin` belongs to the system.

## Use it

| Command                                                   | Prints                                                                                |
| :-------------------------------------------------------- | :------------------------------------------------------------------------------------ |
| `tokenmeter`                                              | A line for each window: `Weekly   69% used   resets in 4h 20m`, and the reading's age |
| `tokenmeter --json`                                       | The same as JSON, for a script                                                        |
| `tokenmeter --left`, `--used`                             | The figures as what is left or used, whatever the app shows                           |
| `tokenmeter stats --range month\|quarter\|year\|lifetime` | The suggestion, each window's summary, the tokens and cost by model                   |
| `tokenmeter stats --json`                                 | The same as JSON                                                                      |

It reads what the app last saw, so the app must be running for the figures to be fresh. It exits with **0** for a fresh reading,
**1** when there is nothing to read (the app never ran), and **2** when the reading is older than 10 minutes.

The JSON has `"version": 1`. Within a version fields are only added, never renamed or removed, so a script that reads it keeps working.
Fractions are from 0 to 1; dates are ISO 8601.

## What it does not do

It does not read the logs, run Claude Code or go on the network: it prints what the app keeps, from
`~/Library/Application Support/TokenMeter/` ([ADR 0017](../adr/0017-a-command-line-tool.md)).
