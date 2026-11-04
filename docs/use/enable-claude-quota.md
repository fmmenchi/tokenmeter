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
unreadable file alone ([ADR 0004](../adr/0004-the-claude-status-line.md)). The Settings
window says what it did, and its switch **Set up the Claude quota automatically** turns this off.

**For each account.** An entry with a `home` is set up the same way in its own folder: the command written in that folder's
`settings.json` carries the entry's id, so the script writes `~/.tokenmeter/<id>-statusline.json` for it, and `/usage` runs
with `CLAUDE_CONFIG_DIR` set to the folder. The General tab says a line for each account, and a wrapped status line is
restored by account ([Accounts](./accounts.md), [ADR 0014](../adr/0014-accounts-and-the-home-of-a-provider.md)).

**Doing it yourself.** When building from source, `./scripts/install.sh` runs this step before the app
opens. To do only this step:

```bash
./scripts/install-statusline.sh
./scripts/install-statusline.sh claude-work ~/.claude-work   # an account: its id and its folder
```

It does what the app does: copies the script, sets only the `statusLine` key, writes the backup first,
and does nothing if it is already set. If you already have a different status line it leaves it alone
and exits with status 2. Without Claude Code it creates nothing
([ADR 0004](../adr/0004-the-claude-status-line.md)). With an id and a folder it does the same for an
account, and the command it writes carries the id.

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
([ADR 0004](../adr/0004-the-claude-status-line.md)). The app saves your original setting
in `~/.tokenmeter/claude/original-statusline.json`, puts a wrapper in `~/.tokenmeter/claude/` (for an account,
in `~/.tokenmeter/<id>/`), and writes `settings.json.tokenmeter.bak` first. **Restore original** in Settings puts it all back. If you later
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
([ADR 0004](../adr/0004-the-claude-status-line.md),
[ADR 0005](../adr/0005-problems.md)). It never writes to a
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
it to: with **Set up the Claude quota automatically** on, the refresh icon of the panel and a timer of 15 minutes run
`claude -p "/usage"` in the background, in `~/.tokenmeter/claude/`, without a session file. Claude Code reads its own
credentials; tokenmeter reads none. If `claude` is not in `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin` or your
`PATH`, the figure stays as old as the copy and reads with `~`. In **Settings, Providers**, a switch under Claude's windows
turns the line off. See [ADR 0002](../adr/0002-quota-model-and-data-sources.md).

## A plan without the 5-hour limit

Some plans do not have every window (Ultra, formerly Max 20x, has no 5-hour limit). tokenmeter shows only the windows your plan
has: when the usage copy Claude Code keeps in `~/.claude.json` is recent (at most six hours old), lists your other limits and
does not list the 5-hour one, the 5 hours row is not drawn and **Settings, Providers** says so. If the copy cannot be read, is
older or Claude Code is not there, the row stays with "unknown", because nothing says the plan lacks it. See
[ADR 0002](../adr/0002-quota-model-and-data-sources.md).

## Related

- [Data Sources](../develop/data-sources.md)
- [ADR 0002: Claude quota from the status line](../adr/0002-quota-model-and-data-sources.md)
- [ADR 0001: No polling of provider endpoints](../adr/0001-app-architecture.md)
