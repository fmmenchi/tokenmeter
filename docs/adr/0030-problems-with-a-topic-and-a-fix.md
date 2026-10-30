# ADR 0030 — Problems with a topic and an optional fix

Status: proposed (2026-10-30); replaces the notices of [ADR 0027](./0027-notices-in-the-snapshot.md)

## Context

The app can tell about one problem today, as a string in `Snapshot.notices` ([ADR 0027](./0027-notices-in-the-snapshot.md)):
projects that override the Claude status line. Other messages are scattered: the App Group warning in the panel, the
status line captions and the Wrap it and Restore original buttons in Settings. A proposal, `TokenMeter Proposal ·
problems`, chose how to show them: on the widget a small chip with a count on the provider the problems are about, on
the menu bar the same chip with the total, and in the menu-bar panel one banner per problem, with an action when there is
one and a way to dismiss it.

## Decision

A **problem** replaces the notice string:

- `Problem` in `TokenMeterCore`: `id`, `topic`, `message`, optional `detail`, optional `fix`. The `topic` is a provider id
  (`claude`, `chatgpt`, or one from `providers.json`) or `general`, for what concerns the app itself.
- `fix` is a closed set of kinds the app knows how to run: today only **wrap the status line**
  (`ClaudeStatusLine.wrap`). A problem without a fix shows no fix button. `guide` is an optional docs path.
- `Snapshot` carries `problems: [Problem]`, empty by default and absent from older files; `notices` is removed.
- The app computes the problems, not the collector: another status line in use and projects that override it (topic
  `claude`), no App Group (topic `general`). Projects are checked at most every 10 minutes, as in ADR 0027.
- **Where they show:** the widget puts a chip with a count next to the provider's name, counting only that topic's
  problems; the menu-bar item puts the same chip, with the total, after the percentage; the panel shows one banner per
  problem with its topic, message, detail, the fix or "Learn more", and Dismiss.
- A fix runs in the panel, instantly. A fix that needs a window is not offered there, because the panel closes when it
  loses focus. The widget shows no action: it only counts.
- **Dismiss** hides a problem by its `id` until its message changes; the choice is stored in the app's defaults.

### Actions

A problem has **at most one fix**, and always **Dismiss** and **Learn more**. The fixes are a closed set, and each kind has
one label, so the label comes from the kind and is not stored in the problem. The only fix today is
`wrapStatusLine`.

| Action     | Where         | What it does                                                                | After it                               |
| :--------- | :------------ | :-------------------------------------------------------------------------- | :------------------------------------- |
| Wrap it    | a fix         | runs `ClaudeStatusLine.wrap` now                                            | the problem leaves at the next check   |
| Dismiss    | every problem | hides this problem by its `id`, in the app's defaults                       | it returns only if its message changes |
| Learn more | every problem | opens two or three lines in the banner, and a link to a docs page (`guide`) | nothing changes; Hide closes the lines |

**Learn more** says what the action does technically, from its kind: for Wrap it, which file it edits
(`statusLine` in `~/.claude/settings.json`, pointed at a script in `~/.tokenmeter/claude/`), what is saved (the original
setting, and `settings.json.tokenmeter.bak`) and how to undo it (Restore original). For a problem with no fix it says
what is wrong and what to do. Only the link inside it opens the browser. The model therefore carries an optional `guide`
(a docs path) beside the optional `fix`; a guide is not a kind of fix.

A fix has four states: **ready**, **running** (its buttons are disabled and the label reads "Wrapping…"), **failed** (the
error replaces the detail, the button reads "Try again", nothing was changed) and **done** (a quiet line, then the banner
goes). Fix all and Re-check are not part of the chosen design.

## Open

- Whether **Restore original** stays in Settings (when the status line is wrapped) or moves into the panel.
- Whether the widget counts only a provider's problems, or the menu bar's total as well, for the `general` ones.
- How long Dismiss lasts: until the message changes, or until the next launch.

## Consequences

- The snapshot format changes: `notices` goes, `problems` comes. An older widget ignores the new key, a newer one reads
  an older file as having none.
- Every message the app wants to tell is a problem with a topic, so the panel, widget and menu bar cannot disagree.
- The pieces to build: the model and its tests in the core, the checks and the fix actions in `Meter`, the three
  surfaces, and the docs.
- Not verified: that a widget can open a link or run an action (it is not asked to), and the visuals of the chosen
  variants on screen.
