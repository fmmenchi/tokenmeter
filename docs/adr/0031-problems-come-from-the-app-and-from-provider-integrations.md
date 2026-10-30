# ADR 0031 — Problems come from the app and from provider integrations

Status: proposed (2026-10-30); builds on [ADR 0030](./0030-problems-with-a-topic-and-a-fix.md) and on
[ADR 0015](./0015-provider-contract.md) to [0018](./0018-the-config-file-is-the-only-source.md)

## Context

[ADR 0030](./0030-problems-with-a-topic-and-a-fix.md) defines a problem, with a topic and an optional fix. The code has to
produce them without becoming a pile of special cases. Providers are all equal and the common code never names one (ADR
0015 to 0018), yet each provider can have problems of its own and its own ways to solve them: Claude's quota depends on a
status line that has to be set up, Codex needs nothing, and a provider added later may need something else.

## Decision

Everything lives in `Sources/TokenMeterCore/Problems/`, in five small modules, each with one job. Nothing in them names a
provider.

- **`Problem`**: the model of ADR 0030. `topic` is a provider id from `providers.json`, or `general`. `fix`, when there is
  one, is the id of a fix that provider's integration declares.
- **`ProviderIntegration`**: a small protocol, one implementation per provider that needs one. It declares its own
  problems (given the home folder and the time), the fixes it can run (each with an id, a button label and the technical
  explanation that **Learn more** shows), and how to run one. The label and the explanation belong to the integration, so
  the interface and the detector know nothing about what a fix means.
- **`ProblemDetector`**: gathers the problems of the app (the `general` ones, such as a missing App Group) and of each
  configured provider's integration, drops duplicates by `id`, and orders them: `general` first, then providers in the
  order of the config. Registering a source is one line.
- **`FixRunner`**: runs a fix through the integration that declared it and answers done, or failed with the reason.
- **`Dismissals`**: remembers what was hidden, by `id` and message, behind a protocol (the app stores it in its
  defaults, the tests keep it in memory).

How a provider gets an integration: **`providers.json` gains an optional `integration` field** (`"integration":
"claude-status-line"`) and a registry, `Integrations.standard()`, maps each id to its implementation, one line each. A
provider without the field has no problems of its own. An unknown id is a `general` problem ("integration not found"),
not a crash. Adding a provider's problems means one implementation and one line of config; the detector, the model and
the interface do not change.

Claude's integration is the first: it wraps `ClaudeStatusLine` and `ProjectStatusLines`, which already exist, and
declares the problems of ADR 0030 and the fix `wrapStatusLine`.

**The rules that keep it modular:**

- A problem source is one file and knows no other source.
- A fix is the descriptor and the action of one integration, nothing more.
- Problem ids are stable and written `<topic>.<check>[.<detail>]`, because Dismiss depends on them.
- The state of a fix (ready, running, failed, done) is state of the interface, kept in `Meter`, and is not in the model
  or in the snapshot.
- `Meter` only orchestrates: at launch and every 10 minutes it runs the detector in the background, applies the
  dismissals, puts the visible problems in `Snapshot.problems` and writes it; after a fix it checks again. The widget
  reads the snapshot and computes nothing.
- Each module has its own tests on throwaway folders, as `ClaudeStatusLine` does.

## Consequences

- A new provider with its own setup costs one file and one config line, and the three surfaces show its problems with
  no change.
- `providers.json` gains an optional field, so [ADR 0018](./0018-the-config-file-is-the-only-source.md)'s file is a little
  larger; an older file keeps working.
- `.agents/doc/architecture.md` says the core does no I/O beyond reading logs, which `ClaudeStatusLine` already stopped
  being true of; the rule is updated with the first commit that touches it.
- `Meter` still names Claude for its own settings switch (ADR 0024). That is not refactored here.
- Not verified: how many providers will ever need an integration, and that the widget reads the new snapshot field. The
  change is additive, as it was for `notices`.

## Order of work

One commit each, three files at most: the model and its tests; the detector and the app's own problems; the integration
protocol and the registry with `providers.json`; Claude's integration; the runner and Dismissals; the snapshot field;
`Meter`; the three surfaces; the docs. The open points of ADR 0030 are settled before the code that needs them (Dismiss
before `Dismissals`, Restore original before the surfaces).
