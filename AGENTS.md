# AGENTS.md

Operating contract for this repository.

## Project

`tokenmeter` — a macOS widget and menu-bar item that monitors the remaining quota of Claude and
ChatGPT plans. Stack: SwiftUI, WidgetKit, `MenuBarExtra` ([ADR 0001](./docs/adr/0001-app-architecture.md)).
Metric and sources: [ADR 0002](./docs/adr/0002-quota-model-and-data-sources.md).

Gate: `pnpm run check`. Spike: `swift run tokenmeter-probe`.

## Open decisions

- **Claude remaining quota** — comes from the status line (ADR 0002); stale until a session runs.
- **Updates** — Sparkle ([ADR 0011](./docs/adr/0011-updates.md)), released in v0.3.0 (2026-11-02), the first version that can update itself and so installed by hand; the signing key's public half is in `project.yml` and a backup of the private half was made by the author in a password manager (not verified by the agent). Unverified: the widget refreshing after a real update, the check started from the menu with a click, a download with Gatekeeper's quarantine, a migration run by a real update, and the feed read by the app itself (curl read it).
- **Notifications** — released in v0.4.0 (2026-11-02), built ([ADR 0012](./docs/adr/0012-limit-notices.md)), the rule is tested in the core; unverified are the permission prompt, a notice on a real Mac, a click on it, Focus modes and the page the button opens in System Settings.
- **Notarized release** — v0.4.0 is published, signed and notarized (ADR 0008); the widget was verified on the author's Mac with the Developer ID build of v0.2.0, and the double click on another Mac is unverified.

## Topic index (`.agents/doc/`)

| Topic                                           | Read when                                            |
| ----------------------------------------------- | ---------------------------------------------------- |
| [architecture](./.agents/doc/architecture.md)   | deciding where a file goes, quota-source rules       |
| [workflow](./.agents/doc/workflow.md)           | ADRs, commits, branches, hooks, CI                   |
| [features](./.agents/doc/features.md)           | designing or building a feature: proposal, ADR, plan |
| [documentation](./.agents/doc/documentation.md) | writing or moving a page in `docs/`                  |
| [known-issues](./.agents/doc/known-issues.md)   | something odd with logs, Swift 6 or pnpm             |

## How we work

- **A structural decision gets an ADR first**, and is not made until it is written.
- **A feature is a nucleus** of proposal, implementation plan and ADRs in `docs/features/`, built in that order ([features](./.agents/doc/features.md)). The `feature` skill runs the flow and stops at each approval.
- **Never work on `main`.** Every feature or fix is built on its own semantic branch, with conventional commits.
- **Never bypass a hook.**
- **Never push.** Fabio pushes. A finished branch is merged into `main` with a **merge commit** (`git merge --no-ff`), never
  a fast-forward and never a rebase onto `main`.
- **`AGENTS.md` only.** Never add a `CLAUDE.md`.
