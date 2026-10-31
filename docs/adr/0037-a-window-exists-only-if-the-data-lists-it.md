# ADR 0037 — A window exists only if the data lists it

Status: accepted (2026-10-30); extends [ADR 0034](./0034-limits-can-be-scoped-to-a-model.md) and [ADR 0016](./0016-providers-declared-in-a-config-file.md)

## Context

A provider declares its windows once, in `providers.json` (`windows: [300, 10080]`), and every card draws all of them. A
plan can have fewer: Anthropic removed the 5-hour limit from its Ultra plan (formerly Max 20x). On the author's account the
signs are all there: `/usage` prints no "Current session", the usage copy Claude Code keeps has `five_hour` null and a list
of limits with only `weekly_all` and `weekly_scoped`, and the status line has only `seven_day`. The app still draws a grey
"5 hours: unknown" row for it, which says nothing true. A model's limit already depends on the plan
([ADR 0034](./0034-limits-can-be-scoped-to-a-model.md)); the windows of a provider should too.

## Decision

**A window shown in a card is one the plan has, and the data says which.** The configuration no longer decides it alone.

- A quota window of `providers.json` may carry **`existsIf`**: a list in a file (`file`, `each`, `where`, as in ADR 0034) and
  how old that list may be (`maxAgeHours`, 6 by default, read with `observedAt` as before). The window exists only if the list
  has an entry that matches. For Claude's 5 hours: the entry of kind `session` in the usage copy.
- **The window is absent only when the list can be trusted and does not name it**: the file is readable, the list is not
  empty, and it was written within `maxAgeHours`. In every other case (no file, unreadable, empty, old, no Claude Code) the
  window stays as it is today, with "unknown". **Unknown is not absent.**
- The reading says which windows are absent (`ProviderReading.absent`, by length); `SnapshotBuilder` leaves them out, with the
  models that are part of them.
- No plan is named in the code. Which windows exist comes from the data, so a plan that gains or loses a window needs no
  release. A provider without `existsIf` is unchanged, ChatGPT included: its logs declare their own windows.
- **Settings** offers a **selector** built from the windows that exist: one segment for each, chosen independently, in the
  accent colour when on. A provider with one window has one segment; there is no "Both" and no menu, so the same control
  serves any number of windows. This replaces the choice of one window or both of
  [ADR 0035](./0035-provider-cards-order-and-windows-are-preferences.md).
- **A model is a sub-segment under its window**, joined by the bracket of the bars, and is on unless the person turned it
  off (`DisplayPreferences.hiddenModels`), so a model a plan gains later shows up. It is disabled while its window is off,
  and selecting the window turns it on again.
- **Choosing no window hides the provider**, the same preference as the eye of [ADR 0036](./0036-a-provider-can-be-hidden.md),
  and choosing any window shows it again. The one provider left shown cannot lose its last window. Showing a provider with
  the eye selects every window.
- A preference saved for a window that is gone does no harm: if nothing it names is left, every window shows.
- An existing `providers.json` gets `existsIf` on the `claude` 5-hour window once, with a backup, as in
  [ADR 0033](./0033-add-the-claude-integration-to-an-existing-providers-file.md) and ADR 0034.

## Consequences

- The menu-bar percentage counts only the windows that exist.
- The card of a plan without the 5 hours is shorter, and the medium widget shows part of the next card.
- A window can come back: when a fresh list names it again the row returns.
- Not verified: a plan that still has the 5 hours (the author's has not), and whether Claude Code ever leaves the entry out of
  the list while the plan has the limit.
