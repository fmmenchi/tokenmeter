# AGENTS.md

Operating contract for this repository.

## Project

`tokenmeter` — a macOS widget and menu-bar item that monitors the remaining quota of Claude and
ChatGPT plans. Stack: SwiftUI, WidgetKit, `MenuBarExtra` ([ADR 0001](./docs/adr/0001-stack-swiftui-widgetkit.md)).
Metric and sources: [ADR 0002](./docs/adr/0002-metric-and-data-sources.md).

Gate: `pnpm run check`. Spike: `swift run tokenmeter-probe`.

## Open decisions

- **Claude remaining quota** — comes from the status line (ADR 0005); stale until a session runs.
- **Notarized release** — signing works, the first Apple notarization is pending (ADR 0021); the widget on a notarized build is unverified.

## Topic index (`.agents/doc/`)

| Topic                                         | Read when                                            |
| --------------------------------------------- | ---------------------------------------------------- |
| [architecture](./.agents/doc/architecture.md) | deciding where a file goes, quota-source rules       |
| [workflow](./.agents/doc/workflow.md)         | ADRs, commits, branches, hooks, CI                   |
| [features](./.agents/doc/features.md)         | designing or building a feature: proposal, ADR, plan |
| [known-issues](./.agents/doc/known-issues.md) | something odd with logs, Swift 6 or pnpm             |

## How we work

- **A structural decision gets an ADR first**, and is not made until it is written.
- **A feature is a nucleus** of proposal, implementation plan and ADRs in `docs/features/`, built in that order ([features](./.agents/doc/features.md)).
- **Never work on `main`.** Semantic branch, conventional commits.
- **Never bypass a hook.**
- **Never push, never merge.** Fabio does both.
- **`AGENTS.md` only.** Never add a `CLAUDE.md`.
