# ADR 0033 — Add the Claude integration to an existing providers file

Status: accepted (2026-10-30); narrows [ADR 0018](./0018-the-config-file-is-the-only-source-of-providers.md)

## Context

[ADR 0031](./0031-problems-come-from-the-app-and-from-provider-integrations.md) gives `providers.json` an optional
`integration` field, and the Claude entry of the seed now carries `"integration": "claude-status-line"`. A file written
before that has no such field, and [ADR 0018](./0018-the-config-file-is-the-only-source-of-providers.md) says an existing
file is never changed by an update: the seed is never merged over what the user has. Left alone, the Claude problems and
the **Wrap it** fix would never show for anyone who already ran the app, which includes the author.

## Decision

The app makes **one narrow, additive change** to an existing file, and nothing else:

- If the file is valid, version 1, and has a provider whose `id` is `claude` **without an `integration` key**, the app
  adds `"integration": "claude-status-line"` to that entry.
- Before writing, it saves the file as `providers.json.tokenmeter.bak` beside it, replacing an older copy.
- If the key is already there, whatever its value (including an empty one chosen on purpose), nothing is touched. A file
  that cannot be read as the expected JSON is not touched either; the rest of ADR 0018 stands.
- It runs where the providers are loaded, so it is idempotent: after the first run there is nothing left to add.
- It is a rule for this one field. A later field needs its own decision; the migration is not a general merge.

## Consequences

- The Claude problems appear for existing users with no step on their part.
- The file is written back as JSON with two-space indentation and **keys sorted alphabetically** within each object, so
  its layout may change once. The order of providers and every value are kept. The `.bak` file keeps the original text.
- A user who removes the `integration` line gets it back on the next run; to opt out they set it to an empty string.
- Not verified: how this behaves on a file edited by hand with unusual formatting, beyond the tests.
