---
title: Commands and Files
sidebar_label: Commands and Files
sidebar_position: 3
---

# Commands and Files

Every command, script, file and data shape in one place.

## Commands

| Command                           | What it does                                                             |
| :-------------------------------- | :----------------------------------------------------------------------- |
| `swift build`                     | Builds `TokenMeterCore` and the probe.                                   |
| `swift test`                      | Runs the core tests (XCTest).                                            |
| `swift run tokenmeter-probe`      | Prints each provider's windows with tokens and remaining quota.          |
| `xcodegen generate`               | Regenerates `TokenMeter.xcodeproj` from `project.yml`.                   |
| `pnpm install`                    | Installs the Node tooling (commitlint, husky, Prettier, Docusaurus).     |
| `pnpm run check`                  | The gate: Prettier check, `swift test`, Docusaurus build.                |
| `pnpm run docs:start`             | Serves this site locally with hot reload.                                |
| `pnpm run docs:build`             | Builds the site; broken links fail the build.                            |
| `./scripts/install.sh`            | Builds the app, installs it in `/Applications`, sets up the status line. |
| `./scripts/install-statusline.sh` | Only the Claude status line: copies the script, sets `statusLine`.       |
| `pnpm run scripts:test`           | Tests the status-line installer on throwaway home directories.           |

The probe output looks like:

```text
Claude (Max 20x)
  5h: 575663908 tokens (in 4200, out 1230025, cache r/w 568384240/6045443) — 75% left [reported]
  7d: 5104412950 tokens (in 70299, out 12975652, cache r/w 5024475829/66891170) — 67% left [reported]
ChatGPT (Team)
  5h: 0 tokens (in 0, out 0, cache r/w 0/0) — 100% left [reset]
  7d: 302342293 tokens (in 9344986, out 524475, cache r/w 292472832/0) — 53% left [reported]
```

Unlike the panel, the probe prints the raw token total including cache reads.

## Files

| Path                                                                     | Written by                      | Read by                    |
| :----------------------------------------------------------------------- | :------------------------------ | :------------------------- |
| `~/.claude/projects/**/*.jsonl`                                          | Claude Code                     | the app and the probe      |
| `~/.codex/sessions/**/rollout-*.jsonl`                                   | Codex CLI                       | the app and the probe      |
| `~/.claude.json`                                                         | Claude Code                     | the app (plan only)        |
| `~/.tokenmeter/providers.json`                                           | the app on first run, then you  | the app and the probe      |
| `~/.tokenmeter/claude-statusline.sh`                                     | `scripts/install-statusline.sh` | Claude Code (`statusLine`) |
| `~/.tokenmeter/claude-statusline.json`                                   | `claude-statusline.sh`          | the app and the probe      |
| `~/Library/Group Containers/group.com.fmmenchi.tokenmeter/snapshot.json` | the app                         | the widget                 |
| `Local.xcconfig`                                                         | you (git-ignored)               | the Xcode build            |

## The snapshot

`snapshot.json` is what the widget renders. Dates are ISO 8601.

| Field                        | Type           | Description                                                       |
| :--------------------------- | :------------- | :---------------------------------------------------------------- |
| `generatedAt`                | date           | When the app built the snapshot.                                  |
| `providers[].provider`       | string         | The provider id, for example `claude` or `chatgpt`.               |
| `providers[].title`          | string         | Display name. Older snapshots lack it and show the id.            |
| `providers[].plan`           | string, option | Subscription label such as `Max 20x`.                             |
| `providers[].quotaUpdatedAt` | date, optional | When the provider's quota was last written.                       |
| `providers[].setupHint`      | string, option | Shown while no quota has been seen.                               |
| `providers[].windows[]`      | array          | One entry per window the provider declares, `5h` then `7d` today. |

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
