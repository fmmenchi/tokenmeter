---
title: Troubleshooting
sidebar_label: Troubleshooting
sidebar_position: 5
---

# Troubleshooting

Find the symptom, read the cause, apply the fix.

## Intent

Most surprises are not bugs: the data tokenmeter reads is old, partial or absent. Start with
`swift run tokenmeter-probe`. If the probe is right and the panel is wrong, the problem is in the
app; if both are wrong, it is in the data.

## Bars

| Symptom                                                       | Cause                                                                                   | Fix                                                                                              |
| :------------------------------------------------------------ | :-------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------- |
| Claude bars are grey and empty, "status line has not run yet" | `statusLine` is not configured, or no session has run since.                            | Follow [Enable the Claude Quota](./enable-claude-quota.md), then send a message in Claude Code.  |
| A bar is dimmed with `~` and "seen 3h ago"                    | The provider last reported it hours ago.                                                | Use the CLI; it refreshes on the next report. Use since then can only have lowered it.           |
| ChatGPT 5h shows `~100%`, "window reset · not used since"     | The last Codex report is for a window that has ended and you have not used Codex since. | Nothing to fix: it is inferred, not reported. It becomes a real figure on your next Codex use.   |
| ChatGPT shows only consumption                                | Codex logs carry `rate_limits: null`, or you only use ChatGPT on the web.               | Web and desktop use is not visible to tokenmeter ([Data Sources](../reference/data-sources.md)). |
| Numbers differ from claude.ai or chatgpt.com                  | Those apps are not seen, and the plans count differently.                               | Trust the percentage; treat tokens as local traffic.                                             |
| Token counts are far below the probe's                        | The panel shows input + output; the probe includes cache reads.                         | Expected.                                                                                        |

## App and widget

| Symptom                                             | Cause                                                                                  | Fix                                                                                                                              |
| :-------------------------------------------------- | :------------------------------------------------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- |
| Panel warns "No App Group"                          | No signing team in `Local.xcconfig`.                                                   | Set `DEVELOPMENT_TEAM` ([Install and Run](./install-and-run.md)), regenerate and rebuild.                                        |
| Widget says "Open tokenmeter once to publish usage" | The app is not running, or it could not write the snapshot.                            | Start the app. If it persists, check the App Group entitlement is in the signed build.                                           |
| No gauge icon in the menu bar                       | The app is not running, or the icon is in the overflow.                                | `pgrep -fl TokenMeter`; relaunch; check menu-bar overflow.                                                                       |
| The app does not start after a restart              | It never registered, you turned the switch off, or you ran a copy from a build folder. | Run the copy in `/Applications` and check the **Launch at login** switch in the panel and System Settings, General, Login Items. |
| First launch takes several seconds to show data     | The first read scans a week of logs.                                                   | Expected; later refreshes read only new bytes ([ADR 0004](../adr/0004-incremental-log-scanning.md)).                             |

:::caution[Personal Team]
Free Personal Teams may not support App Groups on macOS. The signed build here carried the group
entitlement, but whether the widget actually reads the snapshot under a Personal Team was not
confirmed. If the widget stays empty with the app running, that is the first thing to suspect.
:::

## Build

| Symptom                                                   | Cause                                                               | Fix                                                       |
| :-------------------------------------------------------- | :------------------------------------------------------------------ | :-------------------------------------------------------- |
| `Build input file cannot be found` in `xcodebuild`        | A source file was added or removed after the project was generated. | `xcodegen generate`, then build again.                    |
| `ERR_PNPM_IGNORED_BUILDS`                                 | A new dependency has a build script pnpm does not allow.            | Decide it in `pnpm-workspace.yaml` under `allowBuilds`.   |
| Swift 6 error about `ISO8601DateFormatter` not `Sendable` | Shared static formatter.                                            | Use `Date.ISO8601FormatStyle` as `Dates.swift` does.      |
| Commit or push rejected by a hook                         | Message or branch name outside the vocabulary.                      | See [Contribute](./contribute.md). Never bypass the hook. |

## Related

- [Reading the Bars](../reference/bars.md)
- [Data Sources](../reference/data-sources.md)
