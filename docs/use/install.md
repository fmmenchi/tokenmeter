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

The current release is [v0.5.0](https://github.com/fmmenchi/tokenmeter/releases/tag/v0.5.0). It is signed with a Developer ID
certificate and notarized by Apple, so it opens with a double click. It is not on the Mac App Store: the app reads the logs and
settings of the CLIs, which the App Store sandbox does not allow.

1. Download `TokenMeter-v0.5.0.zip` from the release page and open it. Its SHA-256 is in `TokenMeter-v0.5.0.zip.sha256` and in the
   release notes.
2. Drag `TokenMeter.app` to `/Applications` and open it.
3. A gauge icon appears in the menu bar. There is no Dock icon.

From the first version with updates, the app updates itself ([Updates](./updates.md)). Until then, or if you turned that off, quit
the app, drag the new `TokenMeter.app` over the old one in `/Applications` and open it. Your settings and the history the stats
are drawn from stay where they are.

To build it yourself instead, follow [Build and Run](../develop/build-and-run.md), which needs Xcode, XcodeGen and an Apple
developer account.

## After the first launch

- The app registers itself to **start at login**. You can turn that off in Settings, from the panel.
- **Claude quota**: the app sets up Claude's status line itself at every launch when Claude Code is
  installed ([Enable the Claude Quota](./enable-claude-quota.md)). Without it the Claude bars show tokens used but not what is left.
- **Widget**: [Add the Widget](./add-the-widget.md).
- **Stats**: the chart icon of the panel. The first launch of a version with the stats reads every log the tools still keep, which
  takes a minute or two once ([Reading the Stats](./stats.md)).

## Uninstall

Quit the app from the panel, delete `/Applications/TokenMeter.app`, and remove `~/.tokenmeter/` and
`~/Library/Application Support/TokenMeter/` (the history the stats are drawn from). If
you set the Claude status line, remove the `statusLine` entry from `~/.claude/settings.json` (the
installer left a `settings.json.tokenmeter.bak` with the original).

## Related

- [What tokenmeter does](./what-it-does.md)
- [Troubleshooting](./troubleshooting.md)
