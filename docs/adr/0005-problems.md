# ADR 0005 — Problems: a catalogue the app and the provider integrations feed, shown the same way everywhere

Status: accepted (2026-10-30, consolidated 2026-11-02 from the ADRs on problems with a topic and a fix, and on where they come from; amended 2026-11-03 with the failures of the app itself, accepted by Fabio)

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
- **A failure the app meets while it runs is a problem too, never only a log line** (amended 2026-11-03). Three `general` kinds
  join the census: `general.providersfile` (`providers.json` exists and cannot be used, so the app runs on the built-in list and
  leaves the file as it is), `general.snapshotwrite` (the snapshot the widget reads could not be written, so the widget shows
  what it had) and `general.usagerefresh` (Claude Code did not answer `/usage` in time or failed, so the model limits stop
  moving; Claude Code not being installed is not a problem). They have no fix. `AppProblems.check` takes what each one needs as
  plain values and does no I/O, as for the App Group; `Meter` keeps the last outcome of each and the problem goes when the
  outcome is good again.
- **The main actor does no disk I/O** (amended 2026-11-03). Opening the usage store (which may migrate it), setting up the
  Claude status line and writing the snapshot run off it, in order, and report back; `ClaudeUsageRefresh` waits for its process
  without holding a thread. What the views read stays on the main actor.
- **`Meter` only orchestrates:** at launch and every 10 minutes it runs the detector in the background, applies the dismissals,
  writes the visible problems into the snapshot and checks again after a fix. The widget reads and computes nothing.

## Consequences

- A new provider with its own setup costs one file and one config line, and the three surfaces show its problems with no change.
- The snapshot gains `problems`; an older widget ignores it, and a newer one reads an older file as having none.
- A broken `providers.json`, a full disk and a missing answer from Claude Code now show in the panel, the widget chip and the dot,
  where before they were a line in Console. A failure that comes back every minute is one problem, not many: the id is stable.
- At launch the stats view says that the history is being opened until the store answers, instead of waiting on the main thread.
- `Meter` still names Claude for its settings switch. Not verified: that a widget can open a link or run an action (it is not
  asked to).
