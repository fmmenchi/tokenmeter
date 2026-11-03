# ADR 0005 — Problems: a catalogue the app and the provider integrations feed, shown the same way everywhere

Status: accepted (2026-10-30, consolidated 2026-11-02 from the ADRs on problems with a topic and a fix, and on where they come from)

## Context

Messages about what is wrong were scattered (the App Group warning, the status line captions, buttons in Settings), and the code
had to produce them without becoming a pile of special cases. Providers are equal and the common code names none
([ADR 0003](./0003-providers-in-one-config-file.md)), yet each can have problems of its own and ways to solve them.

## Decision

- **A problem** is `id`, `topic` (a provider id or `general`), `message`, an optional `detail`, `explanation` and `guide`, and an
  optional `fix`. `Snapshot.problems` carries them. The id is stable and written `<topic>.<check>[.<detail>]`, because Dismiss
  depends on it.
- **Every problem is catalogued** as a `ProblemKind` (id, topic, summary, explanation, guide, fix): the app and each integration
  declare their kinds, a check only decides whether a kind applies and what the message says this time.
- **Five small modules in `Sources/TokenMeterCore/Problems/`**, none naming a provider: `Problem`; `ProviderIntegration` (a protocol,
  one implementation per provider that needs one, which declares its kinds, reports them, and declares and runs its fixes, with
  their labels and explanations); `ProblemDetector` (gathers the app's `general` problems and each configured provider's, drops
  duplicates by id, orders `general` first and then providers in config order); `FixRunner`; `Dismissals` (by id and message,
  behind a protocol: defaults in the app, memory in tests).
- **A provider gets an integration through an optional `integration` field** of `providers.json` and a registry,
  `Integrations.standard()`, one line each. An unknown id is a `general` problem, not a crash. Claude's integration wraps
  `ClaudeStatusLine` and `ProjectStatusLines` and declares the fix `wrapStatusLine` ([ADR 0004](./0004-the-claude-status-line.md)).
- **A problem has at most one fix**, from a closed set, with its label from the kind; always **Dismiss**, which hides it until its
  message changes, and **Learn more**, which says what is wrong or what the fix does technically, with a link to a docs page. A fix
  runs in the panel at once and has four states (ready, running, failed, done), kept in `Meter` and not in the model or the snapshot.
- **Where they show:** the panel shows a banner for each; the widget puts a chip with a count beside the provider's name and
  counts only that topic, with no action; the menu-bar icon carries a dot while the panel lists one (since v0.3.0, which removed the percentage and the count from the menu bar).
- **`Meter` only orchestrates:** at launch and every 10 minutes it runs the detector in the background, applies the dismissals,
  writes the visible problems into the snapshot and checks again after a fix. The widget reads and computes nothing.

## Consequences

- A new provider with its own setup costs one file and one config line, and the three surfaces show its problems with no change.
- The snapshot gains `problems`; an older widget ignores it, and a newer one reads an older file as having none.
- `Meter` still names Claude for its settings switch. Not verified: that a widget can open a link or run an action (it is not
  asked to).
