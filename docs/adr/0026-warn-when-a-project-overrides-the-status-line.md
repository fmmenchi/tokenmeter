# ADR 0026 — Warn when a project overrides the status line

Status: accepted (2026-10-30); builds on [ADR 0025](./0025-wrap-an-existing-claude-status-line.md); the warning also reaches the widget and the panel ([ADR 0027](./0027-notices-in-the-snapshot.md))

## Context

The status line tokenmeter sets lives in `~/.claude/settings.json`. Claude Code gives project settings
(`.claude/settings.json`) and local project settings (`.claude/settings.local.json`) priority over the
user ones, so a project with its own `statusLine` replaces ours there and the Claude quota stops being
written while a session runs in that project. The quota belongs to the account, so a session
elsewhere refreshes it, but someone who works only in that project sees frozen bars with no hint why.

Fixing it would mean writing into project folders, and a tracked `.claude/settings.json` would carry a
path of one person's home into a shared repository. That was weighed and not chosen: the app warns, and
the person decides.

## Decision

At launch, once Claude's status line feeds tokenmeter (set, already set or wrapped), the app looks, **read
only**, for projects that override it:

- the projects are the working directories recorded in Claude Code's transcripts
  (`~/.claude/projects/*/*.jsonl`, field `cwd`), for sessions touched in the last 30 days, at most 200,
  and only folders that still exist; the home folder itself is skipped, its settings are the user ones;
- the status line in force in a project is the first one defined in `.claude/settings.local.json`, then
  `.claude/settings.json`;
- it counts as overriding unless its command runs `~/.tokenmeter/claude-statusline.sh` or the wrapper
  (the command text names either).

Settings shows a warning with the first projects and the count of the rest, and the way out: wrap that
project's status line so it also pipes its input to the tokenmeter script
([Enable the Claude Quota](../use/enable-claude-quota.md)). Nothing is written to any project, ever.

## Consequences

- A frozen Claude bar has a visible cause, and the fix stays in the project's own hands.
- The check reads up to 200 small files at launch, off the main thread.
- A `cwd` is read from the transcript's first lines; a project whose transcripts carry none is not
  checked. Projects whose settings are managed or passed on the command line are not seen.
