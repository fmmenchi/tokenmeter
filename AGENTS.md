# AGENTS.md

Operating contract for this repository.

## Project

`tokenmeter` — a macOS widget and menu-bar item that monitors AI consumption. Nothing is decided
yet: the stack and the data sources are the first ADRs.

## Open decisions

- **Stack** — SwiftUI with WidgetKit and `MenuBarExtra`, or a web runtime. Desktop and
  Notification Center widgets are WidgetKit-only.
- **What is measured** — API spend in tokens and cost, subscription plan limits (rolling
  windows, weekly caps), or both. Plan limits are not always expressed in tokens.
- **Where the numbers come from** — provider APIs, local logs, or both.

## How we work

- **A structural decision gets an ADR first**, and is not made until it is written.
- **Never work on `main`.** Semantic branch, conventional commits.
- **Never bypass a hook.**
- **Never push, never merge.** Fabio does both.
- **`AGENTS.md` only.** Never add a `CLAUDE.md`.
