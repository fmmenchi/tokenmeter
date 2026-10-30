---
title: Configure Providers
sidebar_label: Configure Providers
sidebar_position: 5
---

# Configure Providers

Add another AI tool to the panel by describing its files, without writing Swift or rebuilding.

## Intent

Show a provider next to Claude and ChatGPT by adding an entry to one JSON file. That file,
`~/.tokenmeter/providers.json`, is the **only** list of providers and every entry in it is equal:
Claude and ChatGPT are two entries the app writes the first time it runs, and you can edit, reorder
or remove them like any other ([ADR 0018](../adr/0018-the-config-file-is-the-only-source.md),
[ADR 0016](../adr/0016-providers-declared-in-a-config-file.md)). A tool whose logs need a rule the
file cannot say is a [source in Swift](../develop/add-a-provider.md) instead.

## Prerequisites

- The tool writes `.jsonl` logs with a timestamp and token counts, and optionally a quota.
- Restart the app after editing the file: it is read at start.

## Step 1: Add an entry to `~/.tokenmeter/providers.json`

The file already holds Claude and ChatGPT. Add your provider to the `providers` array:

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

| Field                                          | Meaning                                                                                                                                                                                                       |
| :--------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`, `title`                                  | Unique id and the name on the panel. The order in the file is the order on the panel.                                                                                                                         |
| `windows`                                      | Window lengths in minutes: `300` is `5h`, `10080` is `7d`, anything else shows `45m`.                                                                                                                         |
| `setupHint`                                    | Line shown while no quota has been seen.                                                                                                                                                                      |
| `log.root`                                     | Folder scanned for `.jsonl` files. `~` is expanded.                                                                                                                                                           |
| `log.contains`                                 | Optional text a line must contain. Cheap: applied before decoding. Use it on big logs.                                                                                                                        |
| `log.where`                                    | Optional. Paths that must equal the given strings for a line to count.                                                                                                                                        |
| `log.timestamp`                                | Path of an ISO 8601 timestamp.                                                                                                                                                                                |
| `usage.mode`                                   | `perEvent`: each line is usage. `cumulative`: usage is the growth since the previous line.                                                                                                                    |
| `usage.dedupeBy`                               | Paths whose values identify a message logged more than once; the last line wins.                                                                                                                              |
| `usage.tokens`                                 | `input`, `output`, `cacheRead`, `cacheWrite`: a path, or `{ "path": …, "minus": … }`.                                                                                                                         |
| `quota.file`                                   | JSON file holding the quota. Absent: the quota is read from the log lines.                                                                                                                                    |
| `quota.windows[]`                              | `usedPercent` path; optional `resetsAt` (seconds since 1970, or `"resetsAtFormat": "iso8601"`); `minutes` or `minutesPath`; `at` names the object holding them.                                               |
| `plan.file`, `path`, `stripPrefix`, `labels[]` | Where the plan string is; absent `file`: the log lines. `labels` are ordered rules (`path`, `contains` or `equals`, `label`), the first match wins; otherwise the value, minus `stripPrefix`, is capitalised. |

Paths are dotted keys (`message.usage.input_tokens`). There are no arrays and no expressions.

## Step 2: Check

```bash
swift run tokenmeter-probe
```

The probe lists every provider in the file and prints why the file was ignored if it was. A broken
file is never overwritten: the app runs on Claude and ChatGPT for that run until you fix it.

## Arrange the cards

Each provider is a card in the panel and in the widget. In **Settings, Providers**:

- **Drag** a provider to move its card. The medium widget shows one card fully, so the first card is the one you see
  there.
- **Choose the windows** a card shows: **5 hours**, **Weekly** or **Both** (a provider with other windows lists them
  instead). **Both** is the default, and one window always stays.
- The percentage in the menu bar counts only the windows you show.

The order and the choice are kept by the app, per provider, and never written to `providers.json`. A provider you add
goes last. Both the light and the dark appearance are respected.

## Related

- [Add a Provider](../develop/add-a-provider.md)
- [Data Sources](../develop/data-sources.md)

## Claude and ChatGPT are entries too

Open the file: the first two entries are Claude and ChatGPT, in the same format as yours. Copy one
as the template for a new provider. They are not special: delete the Claude entry and Claude leaves
the panel. If you ever want the original two back, move the file aside and start the app; it writes
them again.

The file is yours once written. An app update does not change it, so a future improvement to how
Claude or ChatGPT are read reaches you only if you take it into your file.
