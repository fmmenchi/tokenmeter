---
title: Commands and Files
sidebar_label: Commands and Files
sidebar_position: 3
---

# Commands and Files

Every command, script, file and data shape in one place.

## Commands

| Command                      | What it does                                                         |
| :--------------------------- | :------------------------------------------------------------------- |
| `swift build`                | Builds `TokenMeterCore` and the probe.                               |
| `swift test`                 | Runs the core tests (XCTest).                                        |
| `swift run tokenmeter-probe` | Prints each provider's windows with tokens and remaining quota.      |
| `xcodegen generate`          | Regenerates `TokenMeter.xcodeproj` from `project.yml`.               |
| `pnpm install`               | Installs the Node tooling (commitlint, husky, Prettier, Docusaurus). |
| `pnpm run check`             | The gate: Prettier check, `swift test`, Docusaurus build.            |
| `pnpm run docs:start`        | Serves this site locally with hot reload.                            |
| `pnpm run docs:build`        | Builds the site; broken links fail the build.                        |

The probe output looks like:

```text
claude
  5h: 240227064 tokens (in 3060, out 819312, cache r/w 235696117/3708575) — 95% left [reported]
chatgpt
  5h: 0 tokens (in 0, out 0, cache r/w 0/0) — 100% left [reset]
codex reported quotas: ["300m 99.0% used", "10080m 47.0% used"]
```

Unlike the panel, the probe prints the raw token total including cache reads.

## Files

| Path                                                                     | Written by                     | Read by               |
| :----------------------------------------------------------------------- | :----------------------------- | :-------------------- |
| `~/.claude/projects/**/*.jsonl`                                          | Claude Code                    | the app and the probe |
| `~/.codex/sessions/**/rollout-*.jsonl`                                   | Codex CLI                      | the app and the probe |
| `~/.tokenmeter/claude-statusline.json`                                   | `scripts/claude-statusline.sh` | the app and the probe |
| `~/Library/Group Containers/group.com.fmmenchi.tokenmeter/snapshot.json` | the app                        | the widget            |
| `Local.xcconfig`                                                         | you (git-ignored)              | the Xcode build       |

## The snapshot

`snapshot.json` is what the widget renders. Dates are ISO 8601.

| Field                   | Type                | Description                                     |
| :---------------------- | :------------------ | :---------------------------------------------- |
| `generatedAt`           | date                | When the app built the snapshot.                |
| `claudeQuotaUpdatedAt`  | date, optional      | When the status line last wrote Claude's quota. |
| `providers[].provider`  | `claude`, `chatgpt` |                                                 |
| `providers[].windows[]` | array               | One entry per window, `5h` then `7d`.           |

Each window:

| Field               | Type                                       | Description                                 |
| :------------------ | :----------------------------------------- | :------------------------------------------ |
| `window`            | `{ name, duration }`                       | `5h` or `7d`, duration in seconds.          |
| `tokens`            | `{ input, output, cacheRead, cacheWrite }` | Tokens seen in the window.                  |
| `remainingFraction` | number 0 to 1, optional                    | Absent when unknown.                        |
| `source`            | `reported`, `reset`, `consumptionOnly`     | Where `remainingFraction` comes from.       |
| `resetsAt`          | date, optional                             | When the provider says the window resets.   |
| `observedAt`        | date, optional                             | When the provider last reported the figure. |

## Related

- [Reading the Bars](./bars.md)
- [Data Sources](./data-sources.md)
