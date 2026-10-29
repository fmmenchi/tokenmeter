---
title: Install tokenmeter
sidebar_label: Install
sidebar_position: 2
---

# Install tokenmeter

## What you need

- A Mac with macOS 14 or later.
- Claude Code and/or the Codex CLI, already used at least once.

## Download

:::caution[Not published yet]
A signed and notarized download, the one that opens with a double click on any Mac, is built by the
scripts in [Package and Distribute](../develop/package-and-distribute.md) and is **not published
yet**. Until it is, installing means building the app: follow
[Build and Run](../develop/build-and-run.md), which needs Xcode, XcodeGen and an Apple developer account.
:::

Once a release exists, the steps will be:

1. Download `TokenMeter-<version>.zip` from the project's releases page and open it.
2. Drag `TokenMeter.app` to `/Applications` and open it.
3. A gauge icon appears in the menu bar. There is no Dock icon.

## After the first launch

- The app registers itself to **start at login**. You can turn that off in Settings, from the panel.
- **Claude quota**: the app sets up Claude's status line itself at every launch when Claude Code is
  installed ([Enable the Claude Quota](./enable-claude-quota.md)). Without it the Claude bars show tokens used but not what is left.
- **Widget**: [Add the Widget](./add-the-widget.md).

## Uninstall

Quit the app from the panel, delete `/Applications/TokenMeter.app`, and remove `~/.tokenmeter/`. If
you set the Claude status line, remove the `statusLine` entry from `~/.claude/settings.json` (the
installer left a `settings.json.tokenmeter.bak` with the original).

## Related

- [What tokenmeter does](./what-it-does.md)
- [Troubleshooting](./troubleshooting.md)
