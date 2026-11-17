---
title: Unused week, plan
sidebar_label: Plan
sidebar_position: 3
---

# Unused week, plan

How the [proposal](./proposal.md) is built. **No ADR**: [ADR 0012](../../adr/0012-limit-notices.md) says that the kinds of notice and
their thresholds change without one. The rule stays a pure function of the core.

## The rule, as built

- `WindowUsage.hasPlentyLeftNearReset(at:)`: the weekly window (not a model's limit, not the 5 hours), a reported figure no older than
  the stale limit, 50% left or more (`LimitNotices.plentyLeftAtLeast`), and under 2 days to its reset (`plentyLeftWithin`).
- `NoticeKind.plentyLeft` is due when that holds; it is the last in urgency, so a window that would also run out tells that first.
- Once for each window and each reset, like the others. A week never used counts: it is the most unused of all.
- The line in the panel uses the same function and needs no switch; the widget does not show it.

## The steps

| Step | Commit                                                                               | Files                                                            |
| :--- | :----------------------------------------------------------------------------------- | :--------------------------------------------------------------- |
| 1    | `feat(core): a weekly with half left in its last two days is plenty left, a notice`  | `LimitNotices.swift`, `LimitNoticesTests.swift`                  |
| 2    | `feat(app): the notice and a line on the weekly bar when most of the week is unused` | `Notifier.swift`, `NotificationsGroup.swift`, `UsageViews.swift` |
| 3    | `docs(use)`: the notice and the line                                                 | `use/notifications.md`, `use/bars.md`                            |
| 4    | `docs(features)`: this folder and its row                                            | this folder, `features/index.md`                                 |

## Tests

Half left with under two days is due, and from 90% an hour before; 49% is not, nor two days exactly; the 5 hours and a model's limit
never are; an old or inferred reading is not; it is told once and not when its switch is off.

## Not verified at the time of writing

- The line on the bar and the notification on screen: they show only in the last two days of a week with half left.
- The fourth switch in the real Settings window.
