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
The app leaves it alone and says so in Settings. Click **Wrap it** there: your status line keeps
printing exactly what it printed, and tokenmeter gets the same input beside it
([ADR 0025](../adr/0025-wrap-an-existing-claude-status-line.md)). The app saves your original setting
in `~/.tokenmeter/claude/original-statusline.json`, puts a wrapper in `~/.tokenmeter/claude/`, and
writes `settings.json.tokenmeter.bak` first. **Restore original** puts it all back. If you later
change `statusLine` by hand, the app does not overwrite it. It never wraps by itself.

By hand, your command must keep printing its own text and pass the same JSON on stdin to
`~/.tokenmeter/claude-statusline.sh`. That script prints only the word `tokenmeter`, so replacing your
command with it removes whatever you see there now.
:::

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

## Related

- [Data Sources](../develop/data-sources.md)
- [ADR 0005: Claude quota from the status line](../adr/0005-claude-quota-from-statusline.md)
- [ADR 0006: No polling of provider endpoints](../adr/0006-no-polling-of-provider-endpoints.md)
