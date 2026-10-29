---
title: Enable the Claude Quota
sidebar_label: Enable Claude Quota
sidebar_position: 2
---

# Enable the Claude Quota

Switch on the one setting that lets tokenmeter see your Claude plan limits.

## Intent

Claude's transcripts carry tokens, not plan limits. The limits come from Claude Code's **status
line**, which has to be pointed at a small script once. Without this step the Claude bars stay
empty and grey, and only token counts show. ChatGPT needs no setup.

## Step 1: Add the status line

`./scripts/install.sh` does this for you. To do only this step:

```bash
./scripts/install-statusline.sh
```

It copies `claude-statusline.sh` to `~/.tokenmeter/` (every time, so the copy is current) and sets
`statusLine` in `~/.claude/settings.json` to point at it. It changes only that key, writes
`settings.json.tokenmeter.bak` first, and does nothing if it is already set. If you already have a
different status line it leaves it alone and exits with status 2. Without Claude Code (no `~/.claude`)
it does nothing and creates nothing
([ADR 0019](../adr/0019-install-sets-up-the-claude-status-line.md)); then see the box below.

By hand, the setting is:

```json
"statusLine": {
  "type": "command",
  "command": "/Users/you/.tokenmeter/claude-statusline.sh"
}
```

To undo it, delete those lines.

:::warning[You already have a status line?]
Wrap it instead of replacing it. Your command must keep printing its own text, and the script has
to receive the same JSON on stdin. The shipped script prints the word `tokenmeter` and nothing
else, so replacing yours with it removes whatever you see there now.
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
values stay and the panel shows how old they are; see [Reading the Bars](../reference/bars.md).
:::

## Related

- [Data Sources](../reference/data-sources.md)
- [ADR 0005: Claude quota from the status line](../adr/0005-claude-quota-from-statusline.md)
- [ADR 0006: No polling of provider endpoints](../adr/0006-no-polling-of-provider-endpoints.md)
