# ADR 0016 — Extra providers declared in a config file

Status: accepted (2026-10-29); the built-ins staying native is superseded by [ADR 0017](./0017-every-provider-through-the-config.md)

## Context

[ADR 0015](./0015-provider-contract.md) made every provider a `ProviderSource` listed in one
place, but adding one still means writing Swift and rebuilding. Fabio wants to configure providers
without recompiling.

What the two real sources need decides what a file must express:

- **Claude:** lines with `type == "assistant"`, tokens under `message.usage`, one event per line,
  deduplicated by `message.id` plus `requestId`, quota in a separate file with fixed 5h and 7d
  windows.
- **Codex:** cumulative counters (an event is the difference between two lines), `input` is
  `input_tokens` minus `cached_input_tokens`, and the quota sits **inside** the same lines, with
  its window length read from the line.

## Decision

`~/.tokenmeter/providers.json` declares **additional** providers; the app turns each into a
`ConfiguredSource` and appends it after the built-in ones in `Providers.standard()`. Claude and
ChatGPT stay native. A file that cannot express their plan label (a rule table) is not worth a
language, and the native readers carry incremental scanning tuned on 7.5 GB of logs (ADR 0004).

The format is JSON with dotted paths and nothing else: no expressions, no scripting.

```json
{
  "version": 1,
  "providers": [
    {
      "id": "gemini",
      "title": "Gemini",
      "windows": [300, 10080],
      "setupHint": "Gemini quota: not reported yet",
      "log": {
        "root": "~/.gemini/sessions",
        "contains": "\"usage\"",
        "where": { "type": "assistant" },
        "timestamp": "timestamp"
      },
      "usage": {
        "mode": "perEvent",
        "dedupeBy": ["message.id", "requestId"],
        "tokens": {
          "input": "message.usage.input_tokens",
          "output": "message.usage.output_tokens",
          "cacheRead": "message.usage.cache_read_input_tokens",
          "cacheWrite": { "path": "message.usage.cache_write_tokens" }
        }
      },
      "quota": {
        "file": "~/.gemini/quota.json",
        "windows": [
          {
            "minutes": 300,
            "usedPercent": "five_hour.used",
            "resetsAt": "five_hour.resets_at"
          }
        ]
      },
      "plan": { "file": "~/.gemini/account.json", "path": "plan" }
    }
  ]
}
```

- **`windows`:** lengths in minutes; the label is derived (`300` → `5h`, `10080` → `7d`).
- **`log`:** a folder of `.jsonl` files. `contains` is a cheap byte filter applied before decoding,
  `where` keeps the lines whose paths equal the given strings, `timestamp` is an ISO 8601 path.
- **`usage`:** `perEvent` makes each line an event (optionally deduplicated by the `dedupeBy` paths the line has,
  last wins; a line with none of them is never merged);
  `cumulative` makes an event the positive difference to the previous line of the same file. A token
  field is a path, or `{ "path": …, "minus": … }` for a difference.
- **`quota` and `plan`:** read from a `file`, or, when `file` is absent, from the log lines (the
  latest by timestamp wins). A quota window gives `usedPercent`, optionally `resetsAt`
  (`epochSeconds` by default, or `iso8601`), and its length as `minutes` or `minutesPath`; `at`
  names the object that holds them. The plan is the raw string, capitalised.

A broken file adds no providers and does not stop the built-in ones; the probe prints why.

## Consequences

- A new provider whose logs fit this shape needs no code and no rebuild.
- The shape is a ceiling: a tool whose logs need a rule (a lookup table, arithmetic beyond one
  subtraction) is a `ProviderSource` in Swift, and that is fine.
- The file is data from the user's own disk, read-only: it names files to read, never commands to
  run.
- `ConfiguredSource` decodes lines generically. Measured on Fabio's real Claude logs (7 days, 7.5 GB,
  debug build) with a configuration equivalent to the native reader: **19,600 events and identical
  token totals** for both; first scan 20 s against 18 s, incremental read 0.12 s against 0.16 s.
  The first comparison differed by nine events: the native reader deduplicates by `message.id` even
  when `requestId` is missing, which the first version of `dedupeBy` did not. That is now the rule
  above, with a test.
