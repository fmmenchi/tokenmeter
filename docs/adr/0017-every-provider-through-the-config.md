# ADR 0017 — Every provider goes through the config

Status: accepted (2026-10-29)

## Context

[ADR 0016](./0016-providers-declared-in-a-config-file.md) kept Claude and ChatGPT native and added a
JSON file for the rest, which left two kinds of provider. Its reasons were the plan label (a rule
table the format could not say) and the speed of the native readers. Since then the speed was
measured on real logs (19,600 events and identical totals, 20 s against 18 s for the first scan,
0.12 s against 0.16 s after) and a configuration equivalent to each native reader gave the same
events, quota and plan, except the plan label.

## Decision

All providers are declared the same way, and Claude and ChatGPT are two entries in the same format.

- **Built-in providers are JSON shipped inside the app** (`DefaultProviders.swift`, a string
  constant, no resource bundle to get lost in the widget). They are decoded at start like any
  other.
- **`~/.tokenmeter/providers.json` adds and overrides.** An entry with the id of a built-in replaces
  it entirely; any other id is appended. A broken file leaves the built-ins as they are.
- **The native readers are deleted** (`ClaudeLogReader`, `CodexLogReader`, `ClaudeQuotaReader`,
  `ClaudePlanReader`, `ClaudeSource`, `CodexSource`, `PlanName.claude` and `.chatgpt`). The scanning
  they shared (`LogFiles`) stays, used by `ConfiguredSource`.
- **The format gains plan labels**, which is what was missing: `plan.labels` is an ordered list of
  rules (`path`, `contains` or `equals`, `label`); the first match wins; with no match the value at
  `plan.path` is shown capitalised, after `plan.stripPrefix` is removed. That is the whole of
  Claude's rule (`max_20x` before the organisation type, unknown types capitalised).
- **`~` is relative to a home directory the source is given**, the real one in the app and a temporary
  one in tests, so the tests run the real built-in configuration end to end.

## Consequences

- One path for every provider, no asymmetry, and less code: the four readers and two sources go.
- The tests that compared the config against the native readers become fixtures with expected values;
  the comparison on real logs was the one-off evidence recorded in ADR 0016.
- Overriding a built-in means writing it whole: there is no partial patch. That is deliberate; a
  merge would be a second language.
- A provider whose logs need a rule beyond equality, `contains` and one subtraction is still a
  `ProviderSource` in Swift, and the protocol stays for that.
