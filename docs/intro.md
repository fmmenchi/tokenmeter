---
slug: /
sidebar_position: 1
---

# tokenmeter

A macOS widget and menu-bar item showing how much of your Claude and ChatGPT plan quota is left.

## Status

Early. What exists today:

- `TokenMeterCore`: reads Claude Code and Codex CLI logs and builds per-window usage.
- `tokenmeter-probe`: prints that usage to the terminal (`swift run tokenmeter-probe`).
- A menu-bar app and a WidgetKit extension, generated with XcodeGen (`xcodegen generate`).
  Copy `Local.xcconfig.example` to `Local.xcconfig` and set your team so the widget can read the
  App Group.

See [Architecture](./architecture.md).

## Honest limits

Plan limits are not expressed in tokens and neither provider publishes an API for them.
A remaining-quota figure is shown only when it comes from the provider's own logs
(`reported`), or inferred after a reset (`reset`). Otherwise the widget shows
consumption only. See [ADR 0002](./adr/0002-metric-and-data-sources.md).
