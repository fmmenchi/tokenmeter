# ADR 0004 — The Claude status line: set up by the app, wrapped on request, never forced

Status: accepted (2026-10-29, consolidated 2026-11-02 from the ADRs on the installer, the app setting it up, wrapping another status line and projects that override it)

## Context

Claude's quota needs a `statusLine` command in `~/.claude/settings.json` ([ADR 0002](./0002-quota-model-and-data-sources.md)). A
manual step is skipped and leaves the Claude bars grey with no error. Editing another tool's settings is a persistent change, so
it needs consent and a way back.

## Decision

- **On every launch, and when its Settings switch is turned on, the app sets the status line up** (`ClaudeStatusLine` in
  `TokenMeterCore`; `scripts/install-statusline.sh` does the same for a source build): no `~/.claude` means Claude Code is not
  installed and nothing is created; the bundled script is copied to `~/.tokenmeter/claude-statusline.sh` when it differs;
  `statusLine` is set **only if none is set**; a backup `settings.json.tokenmeter.bak` is written first; an unreadable file is not
  touched; running again changes nothing. The switch, **Set up the Claude quota automatically**, is on by default and is the
  opt-out: off, the app never touches Claude's settings.
- **Another status line is wrapped only on a click** (**Wrap it**), never at launch. The app saves the original `statusLine` object
  to `~/.tokenmeter/claude/original-statusline.json`, writes `~/.tokenmeter/claude/statusline-wrapper.sh` and points
  `statusLine.command` at it, keeping every other field. The wrapper reads stdin once, hands it to tokenmeter's script and then
  to the original command through `sh -c`, and prints **only the original's output**: a failure on the tokenmeter side never
  changes what the original prints. **Restore original** puts the saved object back and removes the wrapper; if `statusLine` no
  longer points at the wrapper, it is treated as another status line again and the app never overwrites it.
- **A project that overrides the status line is warned about, never fixed.** At launch, once Claude's status line feeds tokenmeter,
  the app looks read only at the projects recorded in Claude Code's transcripts (`cwd`, sessions touched in the last 30 days, at
  most 200, folders that still exist, the home folder skipped) for a `statusLine` in `.claude/settings.local.json` then
  `.claude/settings.json` whose command runs neither tokenmeter's script nor the wrapper. Nothing is written to a project, ever:
  a tracked settings file would carry one person's home path into a shared repository.

## Consequences

- A zip install shows the Claude bars as soon as a session has run, and they work next to a status line someone likes.
- The app writes outside its own folders: `~/.claude/settings.json` (rewritten as JSON, keys sorted, so formatting may change; the
  backup holds the original) and `~/.tokenmeter/`. One more process per status-line refresh, whose cost was not measured.
- A frozen Claude bar has a visible cause, and the fix stays in the project's own hands. The check reads up to 200 small files at
  launch, off the main thread; managed settings and settings passed on the command line are not seen.
- Not verified: how Claude Code treats fields beyond `type`, `command` and `padding` (the code copies the whole object), and the
  behaviour against a real `settings.json`, which the tests do not run.
