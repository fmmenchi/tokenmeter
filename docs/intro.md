---
title: tokenmeter
sidebar_label: Overview
sidebar_position: 0
slug: /
---

# tokenmeter

A macOS menu-bar app and widget showing how much of your **Claude** and **ChatGPT** plan quota is
left, as a bar for the 5-hour window and one for the weekly window.

## What you get

- Two bars per provider, coloured by how much is left, with the time to reset.
- Tokens used under each bar.
- A clear difference between a **fresh** reading, a **stale** one and an **inferred** reset.
- A WidgetKit widget with the same bars on the desktop.

## What it needs

- macOS 14 or later, Xcode, XcodeGen and an Apple signing team.
- Claude Code with a one-line status-line setting, and/or the Codex CLI.

No credentials and no network: tokenmeter only reads files those tools leave on your machine.

:::caution[Status]
Early. Verified: the log readers, the quota for both providers, the bars and the menu-bar app
starting. **Not verified**: the widget on the desktop end to end, and the panel's look on screen
(it was checked only in rendered previews). See [Troubleshooting](./guides/troubleshooting.md).
:::

## 🚀 Guides

1. [Install and Run](./guides/install-and-run.md): build the app and keep it in the menu bar.
2. [Enable the Claude Quota](./guides/enable-claude-quota.md): one setting in Claude Code.
3. [Add the Widget](./guides/add-the-widget.md): the bars on the desktop.
4. [Troubleshooting](./guides/troubleshooting.md) and [Contribute](./guides/contribute.md).

## 🛠 Reference

- [Reading the Bars](./reference/bars.md): colours, the four states, the `~`.
- [Data Sources](./reference/data-sources.md): where each number comes from and what is not seen.
- [Commands and Files](./reference/commands.md): commands, paths and the snapshot format.

## 🏗 Concepts

- [Concepts](./concepts/index.md): the philosophy, the architecture and how a window gets its state.
- [Decisions](./adr): the ADRs behind each choice.
