# ADR 0038 — A window says when it runs out at its pace

Status: accepted (2026-10-31); extends [ADR 0007](./0007-expired-window-reads-as-reset.md) and [ADR 0008](./0008-remember-last-quota-and-flag-stale.md)

## Context

A bar says how much is left, not whether it lasts until the reset, which is the question a person has. The data to answer
it is already in the snapshot: a window has its length, its reset time, the fraction left and when that was reported.

## Decision

**A window whose quota would run out before its reset says when, at the pace it has had since the last reset**
([the proposal](../features/2026-10-31-burn-rate/proposal.md), variant B).

- **The pace is the average since the window began.** The window began at `resetsAt` minus its length. Used so far is
  `1 - remainingFraction`, over the time between the start and `observedAt`. The quota runs out at the start plus
  that time divided by the used fraction.
- **A line appears only when that moment is before the reset**: "at this pace you run out Thursday at 6 pm". When the quota
  lasts, nothing is said: a card with nothing to warn about is the card as it was.
- **Nothing is estimated** unless the figure is `reported`, fresh (the same 10 minutes as ADR 0008), has a reset time in the
  future, something was used, and at least **10% of the window has passed**. Stale, reset, unknown and consumption-only
  windows have no line, and neither has a window whose first minutes are in a burst.
- **The moment is rounded to the hour** and written as "today at 6 pm", "tomorrow at 6 pm" or the weekday; never minutes.
- **It is computed, not stored**, from what the snapshot has, in `TokenMeterCore`, so it is tested without the interface. It
  names no provider, plan or window: it applies to every window with a length and a reset time, ChatGPT's included.
- **Only the panel draws it.** The widget is unchanged. A model's limit has the figure computed like any window, but its
  compact line has no room for a sentence, so it shows none.

## Consequences

- **A pace is an average.** A quiet night counts as slow use, so the estimate runs pessimistic for a person who does not
  work at night, and a burst gives an alarm the next hours disprove.
- **Claude's percentage moves only when Claude Code runs** (ADR 0005), so it is often stale after ten minutes and the line then
  disappears, to come back with the next session. The line is a live warning, not a forecast.
- The 10% and the ten minutes are choices, not measurements.
- Not verified: a ChatGPT window with a real reset time, and the rounded text on screen.
