# ADR 0024 — The app sets up the Claude status line itself

Status: accepted (2026-10-29); amends [ADR 0019](./0019-install-sets-up-the-claude-status-line.md)

## Context

[ADR 0019](./0019-install-sets-up-the-claude-status-line.md) made the installer set up the status line
and said the app would not, because editing another tool's settings from a background app is a
persistent change nobody asked for. That left two holes: someone who installs the app from a zip
never runs the installer, and someone who installs Claude Code after tokenmeter never gets the Claude
bars. Fabio asked that the app do it on every launch when Claude is there.

## Decision

On every launch, and when its Settings switch is turned on, the app runs the same steps as
`scripts/install-statusline.sh`, in Swift (`ClaudeStatusLine` in `TokenMeterCore`):

- no `~/.claude`: Claude Code is not installed; nothing is created, and the next launch looks again;
- the script bundled in the app is copied to `~/.tokenmeter/claude-statusline.sh` when it differs;
- `statusLine` in `~/.claude/settings.json` is set **only if none is set**; a different one is left
  alone and reported, never replaced;
- a backup `settings.json.tokenmeter.bak` is written before the file changes; an unreadable file is
  not touched;
- it is idempotent: with the line already set it changes nothing.

The consent ADR 0019 asked for now comes from a switch in Settings, **Set up the Claude quota
automatically**, on by default. Off, the app never touches Claude's settings, and it stays off.
Removing the status line by hand while the switch is on has it set again at the next launch; the
switch is how to opt out.

`scripts/install-statusline.sh` stays: building from source runs it before the app first opens, and it
is the one-line fallback for a settings file the app declined to touch.

## Consequences

- A zip install shows the Claude bars as soon as a Claude session has run, with no manual step.
- The app now writes outside its own folders: `~/.claude/settings.json` (rewritten as JSON, keys
  sorted, so formatting may change; the backup holds the original) and `~/.tokenmeter/`.
- The behaviour is covered by tests on throwaway home directories; it is not run against a real
  `settings.json` by the tests.
