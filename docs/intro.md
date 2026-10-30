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
- Claude and ChatGPT out of the box, and [more providers from a JSON file](./use/configure-providers.md).

## What it looks like

![The menu-bar panel: a 5-hour and a weekly bar for Claude (Max 20x) and for ChatGPT (Team), with tokens, time to reset and when each reading was taken](./assets/panel.png)

The panel as it looks on a Mac with both CLIs installed: a stale reading is dimmed and marked
`~`, as the weekly ChatGPT bar is. [Reading the Bars](./use/bars.md) explains every state.

## What it needs

**To run it:** macOS 14 or later, and Claude Code and/or the Codex CLI, since both providers are read from the files those tools leave on your machine.

**To build it** (the only way today): Xcode, XcodeGen and an Apple signing team, because the widget reads its data through an App Group. A prebuilt download that is signed with a Developer ID and notarized would need none of these three: the scripts exist ([ADR 0021](./adr/0021-developer-id-signing-and-notarization.md)), a notarized build is not published yet. The zip you can build yourself runs only on the Mac that built it.

No credentials and no network: tokenmeter only reads files those tools leave on your machine.

:::caution[Status]
Early. Verified: the providers read from real logs, the quota for both, the bars, the panel and the
Settings window opened on screen, the app registered to start at login, and the signed build with
the paid team. **Not verified**: the widget on the desktop end to end, a real reboot with launch at
login, and a notarized build. See [Troubleshooting](./use/troubleshooting.md).
:::

## 👤 Use it

For someone who wants the bars and does not build software.

1. [What tokenmeter does](./use/what-it-does.md): what it shows, what it reads, and that it costs no credits.
2. [Install](./use/install.md): the app on the menu bar.
3. [Enable the Claude Quota](./use/enable-claude-quota.md): one setting in Claude Code.
4. [Add the Widget](./use/add-the-widget.md): the bars on the desktop.
5. [Reading the Bars](./use/bars.md): colours, the four states, the `~`.
6. [Configure Providers](./use/configure-providers.md): another AI tool, from a JSON file.
7. [Troubleshooting](./use/troubleshooting.md).

## 🛠 Develop it

For someone who builds, extends or ships it.

1. [Build and Run](./develop/build-and-run.md): Xcode, XcodeGen, a signing team.
2. [Architecture](./develop/architecture.md) and [Core API](./develop/core-api.md): the pieces, the data flow, the public types.
3. [Concepts](./develop/concepts.md): the philosophy and how a window gets its state.
4. [Data Sources](./develop/data-sources.md): where each number comes from and what is not seen.
5. [Add a Provider](./develop/add-a-provider.md): in Swift, when the JSON file cannot say it.
6. [Commands and Files](./develop/commands.md): commands, paths and the snapshot format.
7. [Package and Distribute](./develop/package-and-distribute.md): Developer ID signing and notarization.
8. [Contribute](./develop/contribute.md).

## 🧩 Features

The things tokenmeter does, newest first, each with an overview, its proposal (with its screens) and its implementation plan.

1. [How a feature is written](./features/index.md).
2. [Problems](./features/problems/index.md): the app tells what is wrong and offers a fix (proposed).

## 🧭 Decisions

[The ADRs](./adr) record why each structural choice was made, written before the code.
