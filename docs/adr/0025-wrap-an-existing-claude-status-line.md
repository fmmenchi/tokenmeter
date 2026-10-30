# ADR 0025 — Wrap an existing Claude status line, on request

Status: proposed (2026-10-29); amends [ADR 0024](./0024-the-app-sets-up-the-claude-status-line.md)

## Context

[ADR 0024](./0024-the-app-sets-up-the-claude-status-line.md) sets the status line only when none is
set. With another one in use the app reports it and stops, so the Claude bars stay empty for anyone
who already has a status line. Claude Code runs `statusLine.command` through a shell, so it is a
script path or an inline command, and it hands the session JSON to it on stdin. A wrapper can pass
that same JSON to tokenmeter's script and to the original command.

## Decision

When another status line is set, Settings offers **Wrap it** instead of only reporting it. Nothing
changes without that click: the automatic launch step keeps leaving another status line alone.

On the click, the app:

- saves the original `statusLine` object, as it is, to `~/.tokenmeter/claude-original-statusline.json`
  (flat, with the `claude-` prefix of the files already there; a `claude/` subfolder would need the
  existing two files moved too, which three files do not justify);
- writes `~/.tokenmeter/claude-statusline-wrapper.sh` and points `statusLine.command` at it, keeping
  every other field of the object (`padding` and the like);
- backs `settings.json` up to `settings.json.tokenmeter.bak` first, as in ADR 0024.

The wrapper reads stdin once, hands it to `claude-statusline.sh`, then to the original command
through `sh -c`, and prints **only the original's output**. A failure in the tokenmeter half never
changes what the original prints.

**Restore original** puts the saved object back and removes the wrapper. If `statusLine` no longer
points at the wrapper (changed by hand), the app treats it as another status line again and asks again;
it never overwrites.

## Consequences

- Claude bars work next to a status line someone already likes.
- The app edits a setting that is not its own, which is why it is a click and not a launch step.
- One more process per status-line refresh; the cost is small and was not measured.
- The original command is stored and run by the wrapper through a shell, as Claude Code itself would
  run it; the saved copy is plain text readable by the same user only.
- Not verified before writing the code: how Claude Code treats fields beyond `type`, `command` and
  `padding`. The code copies the whole object, so none is dropped.
