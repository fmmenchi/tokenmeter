---
title: What tokenmeter Does
sidebar_label: What it does
sidebar_position: 1
---

# What tokenmeter Does

A small Mac app that shows, in the menu bar, how much of your **Claude** and **ChatGPT** plan is left.

## What you see

- A **gauge icon** in the menu bar, and nothing else. A **dot** on its corner says that the panel lists a problem worth a look.
- A **panel** when you click it: for each provider, a bar for the **5-hour window** and one for the
  **weekly window**, with the time to reset and the tokens used.
- **Notifications**, if you turn them on, when a window is running out ([Notifications](./notifications.md)).
- A **chart icon** that switches the panel to the **stats**: how each window ended, whether you hit the ceiling and which models used
  the tokens ([Reading the Stats](./stats.md)). The panel always opens on the current quota.
- Optionally the same bars as a **desktop widget**.

[Reading the Bars](./bars.md) explains the colours and the `~` that marks a figure that is not fresh.

## Where the numbers come from

tokenmeter reads files that **Claude Code** and the **Codex CLI** already leave on your Mac:

| For                     | It reads                                                                                             |
| :---------------------- | :--------------------------------------------------------------------------------------------------- |
| Claude usage            | `~/.claude/projects/**/*.jsonl`                                                                      |
| Claude quota            | `~/.tokenmeter/claude-statusline.json`, written by a status line ([guide](./enable-claude-quota.md)) |
| Claude plan             | `~/.claude.json`                                                                                     |
| ChatGPT usage and quota | `~/.codex/sessions/**/rollout-*.jsonl`                                                               |
| The history             | its own file, `~/Library/Application Support/TokenMeter/usage.sqlite`, filled from the files above   |

If you do not use one of the two tools, its entry stays empty; the other keeps working.

## Does it cost anything?

**No credits, no quota, no money.**

- It makes **one network request of its own**: once a day it asks GitHub for the list of versions, to say whether an update is
  out ([Updates](./updates.md)). It sends nothing about you or your use, and you can turn it off. Every 15 minutes it also asks
  Claude Code to run its own `/usage`, so Claude's quota is the account's; Claude Code uses its own credentials and tokenmeter
  never sees them.
- It needs **no login, no API key and no token**, and never asks for one. Where it shows who an account is signed in as, in
  Settings and in a banner, it reads the email the tool left in its folder and keeps nothing else of it ([Accounts](./accounts.md)).
- It does not send messages to a model, so it does not use up your plan. It only reads files that
  already exist.
- The one thing it adds to Claude Code is a status line that **writes a small file** and prints the
  word `tokenmeter` in Claude Code's status bar. The app sets it up for you when Claude Code is
  installed, only if you have no status line of your own, and you can switch that off in Settings.
  It runs on your Mac and uses no tokens.

What it uses is a little CPU while it reads: the first read after launch scans a week of logs and can
take several seconds; later reads only look at new lines, once a minute. The first time you run the version with the stats it reads
every log the tools still keep, once, which took about a minute and a half for 7 GB; the stats say so while it works.

## What it cannot do

- It cannot see usage from other devices or from the web apps: only what the two CLIs wrote here. The quota of Claude is the
  account's, so it reflects them when it is read; the tokens in the stats are only those this Mac counted. Two accounts of the
  same tool are two folders, and two cards ([Accounts](./accounts.md)).
- It keeps no past it did not see: a window it was not running for is shown as not observed, never estimated.
- It does not know a number the provider did not write down. When it infers a reset, it says so
  instead of showing a made-up percentage ([Reading the Bars](./bars.md)).

## Next

1. [Install it](./install.md).
2. [Enable the Claude quota](./enable-claude-quota.md): one setting in Claude Code.
3. [Add the widget](./add-the-widget.md), if you want the desktop bars.
