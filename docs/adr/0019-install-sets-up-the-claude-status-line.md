# ADR 0019 — The installer sets up the Claude status line

Status: accepted (2026-10-29)

## Context

The Claude quota needs a `statusLine` command in `~/.claude/settings.json` ([ADR 0005](./0005-claude-quota-from-statusline.md)).
That was a manual step in a guide: copy a script, edit another tool's settings, remember to repeat the
copy when the script changes. A step that is skipped leaves the Claude bars grey with no error.

## Decision

An installer does it. `scripts/install.sh` builds the app, installs it in `/Applications` and runs
`scripts/install-statusline.sh`, which:

- copies `claude-statusline.sh` to `~/.tokenmeter/` every time, so the copy is never stale;
- sets `statusLine` in `~/.claude/settings.json` to that copy, **only if none is set**;
- leaves a different existing `statusLine` alone, says so and exits with status 2, because replacing
  it would remove whatever the user sees there now (the guide explains how to wrap it);
- writes `settings.json.tokenmeter.bak` before changing the file, and touches nothing but the
  `statusLine` key;
- is idempotent: a second run reports "already set" and changes nothing;
- does not touch an unreadable settings file.

**The app does not do this on its own.** Editing another tool's settings from a background app, with
nobody asking, is a persistent change to something the user did not hand over. The installer is run
by the user, once, on purpose.

## Consequences

- Install is one command and the status line follows it; the stale-copy caveat of ADR 0005 is gone.
- The installer rewrites `settings.json` as JSON (two-space indent, order kept), so formatting
  quirks of the original file may change; the backup holds the original.
- Someone who installs the zip by hand still follows the guide's manual step.
