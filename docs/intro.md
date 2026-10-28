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

The widget and menu-bar app are not built yet; see [Architecture](./architecture.md).

## Honest limits

Plan limits are not expressed in tokens and neither provider publishes an API for them.
A remaining-quota figure is shown only when it comes from the provider's own logs
(`reported`) or from a limit you configured (`estimated`). Otherwise the widget shows
consumption only. See [ADR 0002](./adr/0002-metric-and-data-sources.md).
