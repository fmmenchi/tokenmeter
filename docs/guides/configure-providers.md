---
title: Configure Providers
sidebar_label: Configure Providers
sidebar_position: 8
---

# Configure Providers

Add another AI tool to the panel by describing its files, without writing Swift or rebuilding.

## Intent

Show a provider next to Claude and ChatGPT from a JSON file. Claude and ChatGPT stay built in;
the file adds more ([ADR 0016](../adr/0016-providers-declared-in-a-config-file.md)). A tool whose
logs need a rule the file cannot say is a [source in Swift](./add-a-provider.md) instead.

## Prerequisites

- The tool writes `.jsonl` logs with a timestamp and token counts, and optionally a quota.
- Restart the app after editing the file: it is read at start.

## Step 1: Write `~/.tokenmeter/providers.json`

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
          "output": "message.usage.output_tokens"
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
      }
    }
  ]
}
```

The paths in the example are placeholders: replace them with the ones your tool really writes.

## Reference

| Field               | Meaning                                                                                                                                                         |
| :------------------ | :-------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`, `title`       | Unique id and the name on the panel. An id of a built-in provider is ignored.                                                                                   |
| `windows`           | Window lengths in minutes: `300` is `5h`, `10080` is `7d`, anything else shows `45m`.                                                                           |
| `setupHint`         | Line shown while no quota has been seen.                                                                                                                        |
| `log.root`          | Folder scanned for `.jsonl` files. `~` is expanded.                                                                                                             |
| `log.contains`      | Optional text a line must contain. Cheap: applied before decoding. Use it on big logs.                                                                          |
| `log.where`         | Optional. Paths that must equal the given strings for a line to count.                                                                                          |
| `log.timestamp`     | Path of an ISO 8601 timestamp.                                                                                                                                  |
| `usage.mode`        | `perEvent`: each line is usage. `cumulative`: usage is the growth since the previous line.                                                                      |
| `usage.dedupeBy`    | Paths whose values identify a message logged more than once; the last line wins.                                                                                |
| `usage.tokens`      | `input`, `output`, `cacheRead`, `cacheWrite`: a path, or `{ "path": …, "minus": … }`.                                                                           |
| `quota.file`        | JSON file holding the quota. Absent: the quota is read from the log lines.                                                                                      |
| `quota.windows[]`   | `usedPercent` path; optional `resetsAt` (seconds since 1970, or `"resetsAtFormat": "iso8601"`); `minutes` or `minutesPath`; `at` names the object holding them. |
| `plan.file`, `path` | Where the plan string is. Absent `file`: read from the log lines.                                                                                               |

Paths are dotted keys (`message.usage.input_tokens`). There are no arrays and no expressions.

## Step 2: Check

```bash
swift run tokenmeter-probe
```

The probe lists every provider, built in or not, and prints why the file was ignored if it was. A
broken file never hides Claude and ChatGPT.

## Related

- [Add a Provider](./add-a-provider.md)
- [Data Sources](../reference/data-sources.md)
