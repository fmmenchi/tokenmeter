---
title: Stats, windows as strips, proposal
sidebar_label: Proposal
sidebar_position: 2
---

# Stats, windows as strips, proposal

The design that was chosen. It was drawn as a canvas in Claude, which is deleted once the feature is implemented; this page is what
stays. **Every number in the images is a sample**, from a Max plan that has both windows; the author's own plan has no 5-hour window.

## What changes

| Surface               | What it shows                                                                                                                                                                             |
| :-------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Stats card, open      | Two strips in place of the rows: the **5 hours** over the last 14 days, one block per window, stacked by day; the **weekly** over the range, one block per week. Time runs left to right. |
| A block               | Green when plenty was left, orange under 30% left, red when the ceiling was reached. A weekly block is filled as a bar is. The figure is in the system's tooltip.                         |
| A week not seen       | A dashed block, never a block drawn as if nothing had been used.                                                                                                                          |
| The summary line      | `hit the ceiling 6 of 33 · last Nov 7` above the 5-hour strip, `never reached the ceiling in 4` above the weekly one.                                                                     |
| The verdict           | Counts the 5-hour windows as well as the weekly ones. See the open decision below.                                                                                                        |
| Weekly not known      | A notice says what is missing, and the verdict says it was drawn from the 5 hours alone.                                                                                                  |
| Wizard, pages 5 and 6 | Page 5 describes the strips and the figure on a point; page 6 names the words of the suggestion. See below.                                                                               |

![The Claude card open, with the 5-hour strip, the weekly strip and the tooltip of a block](./proposal-strips.png)

## The verdict

The verdict counts the 5-hour windows. Hitting the ceiling often is the clearest sign that a plan is tight, and it counted for nothing.
When the weekly is not known yet, the verdict is drawn from the 5 hours and a notice says what is missing and that it may change.

![Three verdict boxes: with Move up, without it, and with the weekly not known](./proposal-verdict.png)

## The wizard

Page 5 says the windows are strips, what the colours mean, that a dashed block is a window the app did not see, and that a point shows
the figure. Page 6 names the words of the suggestion and says it counts the 5 hours too. Both pages are drawn here with the strips and,
for page 6, in the two versions of the open decision.

![Wizard page 5, The stats, with the strips outlined](./proposal-wizard-stats.png)

![Wizard page 6, The suggestion, without Move up and with it](./proposal-wizard-suggestion.png)

## Decisions taken in the design

- **Time runs left to right.** The weekly was drawn as rows first, with the date down the side; the author chose the horizontal time for
  both strips.
- **The figure is in the system's tooltip.** Eight ways to give the number were drawn: the hour on each row, one row per day, a reading
  line under the strip, the figure under the lowest block, the tooltip, the strip with the rows on request, only the fill of small bars,
  and the digits under the blocks. The tooltip was chosen: it takes no space and no state, and it is the weakest one at being found.
- **The tooltip follows Show on the bars**, as the rows do today: `18% left` or `82% used`. The colour of a block follows what is left,
  as the bars do.
- **The 5-hour strip is the last 14 days**, whatever the range. The weekly strip is the range, 13 blocks for 3 months.
- **A window the app did not see is dashed.** It was seen only from the day the app first ran this version.
- **The rows of today go**, the 5-hour ones that were never shown and the weekly ones that were. What they said is in the tooltip.

## Open decision

**Move up.** The verdict today says Wait, Stay or Move down. Two versions were drawn: without Move up, the 5-hour ceiling reached often
makes it Stay and the line says the plan is tight; with Move up, the verdict says so and says that the app does not know the size of the
other plan. It changes the verdict, which is the core of the stats, so it is the author's to choose. Page 6 of the wizard follows.

## For the plan

Questions for the code, not decided here:

- The thresholds of the verdict for the 5 hours: how many windows are enough, and what share at the ceiling makes it tight.
- What the 5-hour strip shows for 1 year and Lifetime: the last 14 days, as drawn, and how many weekly blocks fit.
- Each block needs a label for VoiceOver, because a tooltip is not enough.
- The tooltip's text of a 5-hour block: the hour of its end and the figure, from what a reading holds (`resetsAt`, the highest use
  seen, the first and last time it was seen). The store keeps one reading per window, so no curve inside a window is possible.
- The words and the text of the two new verdict lines, and of the notice for the weekly not known, are drafts.
- The Use pages on the stats and on the suggestion, and the wizard's pictures, which are screenshots of the real panel with sample data.

## Not verified

The look on the real app: light and dark, the other skins, and 52 weekly blocks. That the system's tooltip shows in the panel at all.
The colour threshold in the Used reading. The canvas was rendered offline from its files, not opened.
