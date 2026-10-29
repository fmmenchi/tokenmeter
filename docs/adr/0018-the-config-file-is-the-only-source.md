# ADR 0018 — The config file is the only source of providers

Status: accepted (2026-10-29)

## Context

[ADR 0017](./0017-every-provider-through-the-config.md) moved Claude and ChatGPT into the config
format but kept them inside the app as "built-ins", with `~/.tokenmeter/providers.json` adding to
them or replacing one by id. That still left two kinds of provider: some that exist without a file
and some that exist because of it. On Fabio's Mac the file did not even exist, which read as the
feature not being done. The requirement is that all providers are treated the same.

## Decision

`~/.tokenmeter/providers.json` is the **only** list of providers, and every entry in it is equal.

- **First run:** if the file is missing, the app writes it with Claude and ChatGPT as its two
  entries (the seed in `DefaultProviders.swift`), then reads it like any other run.
- **Every run:** the providers are exactly the file's entries, in the file's order. There is no
  merge, no override by id and nothing that appears without being in the file. Removing the Claude
  entry removes Claude.
- **A file that cannot be used** (broken JSON, unknown version, a repeated id) is not overwritten.
  The app falls back to the seed for that run so the panel is not empty, and the probe prints why.
- **The seed is a starting point, not a layer.** It is used to create the file and as the fallback;
  it is never merged over what the user has.

## Consequences

- One path and one rule: a provider is whatever the file says, so adding, removing, reordering or
  editing Claude is the same act as doing it for any other tool.
- The file belongs to the user once written. An app update that improves the seed does not change an
  existing file. The `version` field is where a future migration would hook in.
- The app now writes a file in the user's home on first run. It is not sandboxed and the status-line
  script already writes in the same folder, so no new permission is involved.
- ADR 0017's built-in-and-override rule is superseded; its format, its readers' removal and the
  plan labels stand.
