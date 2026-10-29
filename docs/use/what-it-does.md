---
title: What tokenmeter Does
sidebar_label: What it does
sidebar_position: 1
---

# What tokenmeter Does

A small Mac app that shows, in the menu bar, how much of your **Claude** and **ChatGPT** plan is left.

## What you see

- A **gauge icon** in the menu bar. Next to it, the lowest percentage left across your plans.
- A **panel** when you click it: for each provider, a bar for the **5-hour window** and one for the
  **weekly window**, with the time to reset and the tokens used.
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

If you do not use one of the two tools, its entry stays empty; the other keeps working.

## Does it cost anything?

**No credits, no quota, no money.**

- It makes **no network request**: it never contacts Anthropic, OpenAI or anyone else.
- It needs **no login, no API key and no token**, and never asks for one.
- It does not send messages to a model, so it does not use up your plan. It only reads files that
  already exist.
- The one thing it adds to Claude Code is a status line that **writes a small file** and prints the
  word `tokenmeter` in Claude Code's status bar. That runs on your Mac and uses no tokens.

What it uses is a little CPU while it reads: the first read after launch scans a week of logs and can
take several seconds; later reads only look at new lines, once a minute.

## What it cannot do

- It cannot see usage from other devices or from the web apps: only what the two CLIs wrote here.
- It does not know a number the provider did not write down. When it infers a reset, it says so
  instead of showing a made-up percentage ([Reading the Bars](./bars.md)).

## Next

1. [Install it](./install.md).
2. [Enable the Claude quota](./enable-claude-quota.md): one setting in Claude Code.
3. [Add the widget](./add-the-widget.md), if you want the desktop bars.
