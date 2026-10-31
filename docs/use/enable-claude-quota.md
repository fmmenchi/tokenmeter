---
title: Enable the Claude Quota
sidebar_label: Enable Claude Quota
sidebar_position: 3
---

# Enable the Claude Quota

Switch on the one setting that lets tokenmeter see your Claude plan limits.

## Intent

Claude's transcripts carry tokens, not plan limits. The limits come from Claude Code's **status
line**, which has to be pointed at a small script. Without it the Claude bars stay empty and grey,
and only token counts show. ChatGPT needs no setup.

## Step 1: Let the app do it, or do it yourself

**The app does it.** At every launch, if Claude Code is installed (`~/.claude` exists), tokenmeter
copies the script to `~/.tokenmeter/` and sets `statusLine` in `~/.claude/settings.json`. If you
install Claude Code after tokenmeter, the next launch picks it up. It never replaces a status line
you already have, writes `settings.json.tokenmeter.bak` before changing the file, and leaves an
unreadable file alone ([ADR 0024](../adr/0024-the-app-sets-up-the-claude-status-line.md)). The Settings
window says what it did, and its switch **Set up the Claude quota automatically** turns this off.

**Doing it yourself.** When building from source, `./scripts/install.sh` runs this step before the app
opens. To do only this step:

```bash
./scripts/install-statusline.sh
```

It does what the app does: copies the script, sets only the `statusLine` key, writes the backup first,
and does nothing if it is already set. If you already have a different status line it leaves it alone
and exits with status 2. Without Claude Code it creates nothing
([ADR 0019](../adr/0019-install-sets-up-the-claude-status-line.md)).

By hand, the setting is:

```json
"statusLine": {
  "type": "command",
  "command": "/Users/you/.tokenmeter/claude-statusline.sh"
}
```

To undo it, delete those lines and turn the Settings switch off, or the next launch sets it again.

:::tip[You already have a status line?]
The app leaves it alone and lists it as a problem in the panel. Click **Wrap it** there: your status line keeps
printing exactly what it printed, and tokenmeter gets the same input beside it
([ADR 0025](../adr/0025-wrap-an-existing-claude-status-line.md)). The app saves your original setting
in `~/.tokenmeter/claude/original-statusline.json`, puts a wrapper in `~/.tokenmeter/claude/`, and
writes `settings.json.tokenmeter.bak` first. **Restore original** in Settings puts it all back. If you later
change `statusLine` by hand, the app does not overwrite it. It never wraps by itself.

By hand, your command must keep printing its own text and pass the same JSON on stdin to
`~/.tokenmeter/claude-statusline.sh`. That script prints only the word `tokenmeter`, so replacing your
command with it removes whatever you see there now.
:::

### A project has its own status line

Claude Code gives a project's settings (`.claude/settings.json`, `.claude/settings.local.json`)
priority over `~/.claude/settings.json`. A project that sets its own `statusLine` replaces the one
tokenmeter set, so the Claude quota stops being written while a session runs there. The quota belongs
to the account, so a session in another project refreshes it, but if you only work in that project the
bars stay frozen.

In the background, at launch and then at most every 10 minutes, tokenmeter looks, read only, at the
projects you used in the last 30 days. It adds a problem to the panel naming the ones that override it, and a chip with the count
beside Claude in the widget; nothing blocks
([ADR 0026](../adr/0026-warn-when-a-project-overrides-the-status-line.md),
[ADR 0030](../adr/0030-problems-with-a-topic-and-a-fix.md)). It never writes to a
project: a tracked `.claude/settings.json` would carry a path from your home into a shared repository.
To fix one, make that project's command also pipe its input to the tokenmeter script. In
`.claude/settings.local.json`, which git ignores, that is:

```json
"statusLine": {
  "type": "command",
  "command": "input=$(cat); printf '%s' \"$input\" | ~/.tokenmeter/claude-statusline.sh >/dev/null; printf '%s' \"$input\" | <your command>"
}
```

## Step 2: Trigger it

Send any message in a Claude Code session. The script writes
`~/.tokenmeter/claude-statusline.json`; the app picks it up within a minute, or at once if you open
the panel.

## Step 3: Check it

```bash
cat ~/.tokenmeter/claude-statusline.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('rate_limits'))"
```

You should see a `five_hour` and a `seven_day` entry with `used_percentage` and `resets_at`.

:::tip[Only while Claude Code runs]
The file is rewritten only while a session renders its status line. Between sessions the last
values stay and the panel shows how old they are; see [Reading the Bars](./bars.md).
:::

## A limit for one model

Some plans have a limit for one model that is part of the weekly limit (the usage page shows it, for example, under
**This week**). tokenmeter shows it as a thin line under **Weekly**'s bar, joined to it by a bracket, only when your plan has it. The figure comes from the
usage copy Claude Code keeps in `~/.claude.json`, which Claude Code only refreshes when it runs `/usage`. So tokenmeter asks
it to: with **Set up the Claude quota automatically** on, the **Refresh** button and a timer of 15 minutes run
`claude -p "/usage"` in the background, in `~/.tokenmeter/claude/`, without a session file. Claude Code reads its own
credentials; tokenmeter reads none. If `claude` is not in `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin` or your
`PATH`, the figure stays as old as the copy and reads with `~`. In **Settings, Providers**, a switch under Claude's windows
turns the line off. See [ADR 0034](../adr/0034-limits-can-be-scoped-to-a-model.md).

## Related

- [Data Sources](../develop/data-sources.md)
- [ADR 0005: Claude quota from the status line](../adr/0005-claude-quota-from-statusline.md)
- [ADR 0006: No polling of provider endpoints](../adr/0006-no-polling-of-provider-endpoints.md)
