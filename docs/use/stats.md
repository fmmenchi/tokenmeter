---
title: Reading the Stats
sidebar_label: Stats
sidebar_position: 7
---

# Reading the Stats

What the stats view of the panel says, and what it leaves out on purpose.

## Open it

![The stats view of the panel: a range control, the first card open with its verdict, the 5-hour and the weekly strips and a ring of the models, and the second card closed to a line](../assets/stats.png)

The row of icons at the bottom of the panel has a chart. Click it and the panel shows the stats instead of the current
quota; the icon becomes a gauge, and a click on it takes you back. The panel always opens on the current quota, and the stats are one click away.

## The range

The control at the top picks how far back the stats look: **1 month**, **3 months**, **1 year** or **Lifetime**, which is
everything the app has kept. It changes the tokens by model, how many windows are counted and how many blocks the weekly strip has
(4, 13, 52 or as many as fit); the 5-hour strip is always the last 14 days.

## A card for each provider, closed or open

Each provider that is on has a card, in the order of Settings. **One card is open at a time**, so the panel keeps a height that
fits the screen: the first one until you choose, then the one you opened last, which the panel remembers. Open, a card has the
verdict, the windows that ended as strips and the models as a ring; closed, one line for each window (what the app saw) and one for the models.
**A click anywhere on a card opens it and closes the one that was open**, and a click on the open one closes it. **All providers** is a
card of its own, and counts as one of them: open, the models under their provider, indented, against one total; closed, a bar.

### The verdict

A word at the top of an open card, from percentages only. It counts the 5-hour windows as well as the weekly ones: a window length
counts once it has ended **4 times** in the range, or **12 times** for a window shorter than a day.

| Word          | When                                                                                                                                                                  |
| :------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Wait**      | No window length has ended enough times in the range. Claude's weekly quota is kept from the day the app first ran this version, so it says Wait for the first weeks. |
| **Move up**   | The ceiling was reached at least twice, and in at least 15% of the windows, of a length that counts. It names the window that went there most often.                  |
| **Stay**      | The ceiling was reached, but not often enough for Move up, or the readings were not complete enough to say more, or the lowest margin was under 60% left.             |
| **Move down** | The ceiling was never reached, every reading was seen near the end of its window and the lowest margin was 60% left or more.                                          |

Move up says the ceiling is reached often. It does not say which plan to take, because the size of the other plans is not known, and
it never looks at tokens. The counts, the 15% and the 60% are a choice and not a measurement.

When the weekly limit is not known yet, as Claude's is before the first reply of a session, a notice under the verdict says so: the
verdict is drawn from the 5 hours alone and may change when the weekly figure arrives.

### What an open card lists

Each provider that is on has a card, in the order of Settings. For each window the plan has, a line and a strip of blocks, with time
running from left to right:

| What you see                           | Meaning                                                                                                                                                                                                   |
| :------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The **5 hours** strip                  | The last 14 days, one column for each day with a block for each window that ended in it, the oldest at the bottom. A day with no window is a thin line.                                                   |
| The **weekly** strip                   | One block for each week of the range, filled as a bar is. A dashed block is a week the app did not see: nothing is made up for the gap.                                                                   |
| The colour of a block                  | The colour a bar of what was left would have: green when there was plenty, orange under 40% and red under 15%. A window that reached the ceiling keeps a sliver when the bar would be empty.              |
| A block at half strength               | The last reading was a good while before the window ended, so it may have ended with less.                                                                                                                |
| The tooltip of a block                 | Point at a block for its date and **at most** what was left, the highest use the app saw in it: `Nov 5, 3:00 PM · 0% left`. With [Show on the bars](./bars.md#left-or-used) on Used it reads `100% used`. |
| `hit the ceiling 1 of 4 · last Oct 27` | In how many of the windows in the strip the ceiling was reached (100%), and when it last was.                                                                                                             |
| `never reached the ceiling in 4`       | The windows the app saw, none of which went to 100%.                                                                                                                                                      |
| `not observed`                         | The app saw no window of that length end. Nothing is made up for the gap.                                                                                                                                 |

Every block has a label for VoiceOver with the same text as its tooltip.

## Tokens by model

As a ring, the **first three models** by tokens, input plus output, with the rest as one slice. Hover a row for the count.
**N more models…** opens the rest, and what is under 2% is added into **Other**. Versions of a model add up
(`fable-5` and `fable-5-1` are Fable) and a name with no rule shows as it is; the rules are `usage.families` in
`providers.json` ([format](./configure-providers.md)). A provider whose log does not name the model says so.

## What it does not say

- **No estimate.** There is no size of a plan in tokens, no forecast and no verdict: they would rest on a ratio between tokens
  and the percentage that does not hold, because the percentage is the account's and the tokens are one Mac's.
- **The tokens are only those this Mac counted.** Use on another computer, on the web or in the phone is not in them. Claude's
  quota includes that use; the status line writes its current weekly figure while Claude Code runs. A model's limit is updated
  when you choose **Open /usage** on its card.
- **A window the app did not see is not drawn.** The quota of a window can only be written down while it is seen: Claude's
  history starts the day the app first ran this version, and ChatGPT's from what the Codex logs still hold.

## Where it keeps what it saw

In `~/Library/Application Support/TokenMeter/usage.sqlite`, a small file made by the app. Quit the app and delete it to start
again: the tokens and the models come back from the logs as far as they go, the quota readings do not.

The first time the app runs this version it reads every log the CLIs still keep. On the author's Mac that was 1,304 files,
7.4 GB, and took about a minute and a half off the main thread; after that it reads only what is new.

## Related

- [Reading the Bars](./bars.md)
- [Configure Providers](./configure-providers.md)
- [Data sources](../develop/data-sources.md)
- [Usage stats, the feature](../features/2026-11-02-usage-stats/index.md)
