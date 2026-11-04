---
title: Reading the Bars
sidebar_label: Bars
sidebar_position: 6
---

# Reading the Bars

What each bar, colour, symbol and line of text under it means.

Each provider has two bars: **5 hours** and **Weekly**. A bar shows how much of the window is
**left**, not how much is used. The figure on the right is that percentage, and the line under the
bar is the detail. The figure can read the other way, how much is **used**: see [Left or used](#left-or-used).

## Colour

| Left          | Colour          |
| :------------ | :-------------- |
| 40% or more   | green           |
| 15% up to 40% | orange          |
| under 15%     | red             |
| unknown       | grey, empty bar |

The thresholds are written where the colour is chosen: `tint` in `Shared/UsageViews.swift`, and the same cut-offs in `Shared/Skins/SkinStyle.swift` for a skin.

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
if the data on disk is old ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)). If
there was use after the reset and no new quota was reported, the window stays **Unknown** rather
than claiming to be full ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)).
:::

## Left or used

By default the figure says how much is left (`25% left`) and the bar is filled to it. In Settings, in **General**, **Show on the bars**
changes it to **Used**: the figure says `75% used`, the bar is filled to 75% and the mark moves with it, on the same side as the bar, so
a bar that ends past the mark still means the quota runs out before the reset. The choice is one for the panel and the widget, in every
size and skin ([ADR 0006](../adr/0006-display-preferences.md)).

Three things do not change. **The colour** still follows what is left: a bar at `75% used` is orange, and one at `95% used` is red, because
under 40% and under 15% are left. **The notices** keep saying what is left. **The stats** follow the choice: a window that ended says `35% used` and its bar is filled to it, and the verdict says "went up to 62% used or more" in place of "went down to 38% left or less". And **a window with nothing used** is an empty
bar, `~0% used`, where in `left` a bar that is almost out keeps a small sliver so that it is not drawn as if it were empty.

## Reading the mark

A bar says how much is left, not whether it lasts until the reset. The **mark** on the bar does: it is where the bar would
end if the window were used steadily from its start to its reset ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)).

- **A bar that ends before the mark** means you are going too fast: at this pace the quota runs out before the reset. The
  mark is orange then.
- **A bar that ends after the mark** means the quota lasts until the reset. The mark is the colour of the text.
- **Put the pointer on the bar** to see when. The figure on its label line, "20% left", becomes "out Thu 6 pm" in orange where
  the quota runs out, with a short fade, and goes back when the pointer leaves. Where it lasts the figure does not change:
  the mark already says it. Nothing else moves. The system
  tooltip does not show in a panel of an app with no Dock icon, and a bubble covered the row above.
- **The `i`** beside the provider's name opens a short explanation of the mark, with a link to this section. It closes with
  its `x`, with a second click on the `i` or with a click outside it.

**No mark means nothing can be said**, not that the quota lasts. Nothing is estimated for a reset or unknown window, one
or one with no reset time. A window where nothing was used has a mark and lasts, and so does one with less than a tenth of its time gone: the mark says where the window stands, and it does not say the quota runs out until there is enough of the window to judge.

- **A reading older than ten minutes keeps its mark, at half strength** and measured now, so it moves left as time passes.
  The bar is the last reading, which can only have gone down since. The mark is orange only when the bar is already before
  it, since then the quota runs out even if nothing was used. Where the bar is already before the mark, the hover gives the
  date with a tilde, "~out Thu 6 pm", worked out from the reading and not corrected for use since; otherwise it says nothing, since
  the line of the provider at the bottom already says how old the reading is. ChatGPT is like this
  most of the time: Codex writes its quota only when it runs.
- **The pace is the average since the window began**, so a quiet night counts as slow use and the mark is pessimistic for
  someone who does not work at night.
- **Claude's figure moves only while Claude Code runs**, so after ten minutes its mark goes to half strength, and back to full
  with the next session.
- **A model's limit under Weekly** has its own thin bar with its own mark, and its own figure at the end of its row says when it runs out; its bar shortens to make room for it.
- **The widget has no mark and no hover.** Where a window would run out before its reset, its detail line says so in
  short, in orange: `3.4B tokens · out Thu 6 pm · resets in 3d 14h`. A model's limit has no phrase of its own there.

## Tokens

The line under a bar shows **input + output** tokens seen in that window's own period: from its start, which is its reset
time minus its length, when the provider gave one ([ADR 0002](../adr/0002-quota-model-and-data-sources.md)),
and over the last 5 hours or 7 days when it did not. Cache reads and cache
writes are left out: they make up about 98% of the raw total and say nothing about plan use. The
count comes from local CLI logs only, so it covers Claude Code and Codex and not the web or desktop
apps, and it does not match how the plans count.

## The panel

![The menu-bar panel with its two providers, the quota-age lines and a row of four icons: refresh, the stats, Settings and quit](../assets/panel.png)

| Element                                     | Meaning                                                                                                                                                        |
| :------------------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Claude quota from 3 hours ago`             | When the status line last wrote Claude's quota.                                                                                                                |
| `Claude quota: status line has not run yet` | The status line is not set up or no session has run. See [Enable the Claude Quota](./enable-claude-quota.md).                                                  |
| Orange warning about the App Group          | No signing team: the widget cannot read the snapshot.                                                                                                          |
| The row of icons                            | Refresh (re-reads now, with a spinner while it works), the chart that opens the [stats](./stats.md), Settings, and Quit. Each has a name that a pointer shows. |

The panel also refreshes by itself whenever it opens. The menu-bar item itself is the gauge icon.

## Related

- [Data Sources](../develop/data-sources.md)
- [Troubleshooting](./troubleshooting.md)
