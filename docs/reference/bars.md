---
title: Reading the Bars
sidebar_label: Bars
sidebar_position: 2
---

# Reading the Bars

What each bar, colour, symbol and line of text under it means.

Each provider has two bars: **5 hours** and **Weekly**. A bar shows how much of the window is
**left**, not how much is used. The figure on the right is that percentage, and the line under the
bar is the detail.

## Colour

| Left          | Colour          |
| :------------ | :-------------- |
| 40% or more   | green           |
| 15% up to 40% | orange          |
| under 15%     | red             |
| unknown       | grey, empty bar |

The thresholds are in `tint` in `Shared/UsageViews.swift`.

## The four states

| State        | Looks like                    | Detail line example                         | Meaning                                                                           |
| :----------- | :---------------------------- | :------------------------------------------ | :-------------------------------------------------------------------------------- |
| **Reported** | solid bar, `62% left`         | `1.2M tokens · resets in 2h 9m`             | The provider reported it within the last 10 minutes.                              |
| **Stale**    | dimmed bar, `~12% left`       | `14.2M tokens · seen 3h ago · may be lower` | Last reported more than 10 minutes ago. Use since then can only have lowered it.  |
| **Reset**    | dimmed full bar, `~100% left` | `window reset · not used since`             | The window ended and no use was recorded after it, so it is full again. Inferred. |
| **Unknown**  | grey empty bar, `unknown`     | `no quota · 1.2M tokens`                    | No quota is available for this window. Only consumption is shown.                 |

A `~` before the figure always means "not a fresh provider reading".

:::info[Resets happen on their own]
When a reported window's reset time passes, the bar turns into a **Reset** bar immediately, even
if the data on disk is old ([ADR 0008](../adr/0008-remember-last-quota-and-flag-stale.md)). If
there was use after the reset and no new quota was reported, the window stays **Unknown** rather
than claiming to be full ([ADR 0007](../adr/0007-expired-window-reads-as-reset.md)).
:::

## Tokens

The line under a bar shows **input + output** tokens seen in that window. Cache reads and cache
writes are left out: they make up about 98% of the raw total and say nothing about plan use. The
count comes from local CLI logs only, so it covers Claude Code and Codex and not the web or desktop
apps, and it does not match how the plans count.

## The panel

![The menu-bar panel with its two providers, the three read-age lines and the Refresh, Settings and Quit buttons](../assets/panel.png)

| Element                                     | Meaning                                                                                                               |
| :------------------------------------------ | :-------------------------------------------------------------------------------------------------------------------- |
| `Read 12 seconds ago`                       | When the app last read the files.                                                                                     |
| `Claude quota from 3 hours ago`             | When the status line last wrote Claude's quota.                                                                       |
| `Claude quota: status line has not run yet` | The status line is not set up or no session has run. See [Enable the Claude Quota](../guides/enable-claude-quota.md). |
| Orange warning about the App Group          | No signing team: the widget cannot read the snapshot.                                                                 |
| **Refresh**                                 | Re-reads now and shows a spinner while it works.                                                                      |

The panel also refreshes by itself whenever it opens. The menu-bar item itself is the gauge icon.

## Related

- [Data Sources](./data-sources.md)
- [Troubleshooting](../guides/troubleshooting.md)
