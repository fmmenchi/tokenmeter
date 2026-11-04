---
title: Accounts
sidebar_label: Accounts
sidebar_position: 5.5
---

# Accounts

A work account and a personal one, each with its own card: an account is a folder Claude Code or the Codex CLI reads.

## Intent

Claude Code keeps one login per configuration folder: `~/.claude`, or the folder in `CLAUDE_CONFIG_DIR`. The Codex CLI does the
same with `~/.codex` and `CODEX_HOME`. A person with two accounts has two folders, and tokenmeter can show both: each account is
an entry of `~/.tokenmeter/providers.json` whose `home` names its folder, and everything the app does for a provider, the bars,
the plan, the history, the notices and the status line, it does for that folder
([ADR 0014](../adr/0014-accounts-and-the-home-of-a-provider.md)).

Who has one account changes nothing: the two entries the app writes the first time read `~/.claude` and `~/.codex`.

## Settings, Accounts

The **Accounts** tab of Settings lists the entries of the file: the title, the email the folder is signed in with, the tool, and
the folder when you hover the row. The email is read from the folder and shown here and in the panel's banner only; it is never
written anywhere, and the widget never has it.

- **Add an account…** opens a sheet: the tool, the folder (type it, or **Choose…** opens the system's Open panel on hidden
  folders too), a line that says what the folder holds and who is signed in there, and the title, filled in with the email as
  soon as the folder is one of the tool's. **Add** writes the entry into the file.
- **Edit…** opens the same sheet on an entry: the title and the folder can change, the tool and the id cannot, so the history,
  the order and the notices of the account stay. **Save** writes the entry.
- **Remove…** asks first, and says what goes and what stays: the card leaves the panel and the widget, the entry leaves the file,
  the history stays in the stats, and the folder and its login are not touched. It is disabled on the last account.

The app writes the file the way its migrations do: a copy is kept as `providers.json.tokenmeter.bak`, and the file stays yours.
An entry written by hand is read like the others, and a change by hand wins at the next check, within ten minutes, or at the
next launch.

## The status line and `/usage`, for each account

With **Set up the Claude quota automatically** on, the app sets the status line up in each Claude account's folder, in its
`settings.json`, with the account's id as the script's argument, so each account writes a file of its own under `~/.tokenmeter/`.
It asks Claude Code for each account's `/usage` in turn, every 15 minutes and when you refresh. The General tab says what it
found for each account, and **Restore original** beside an account puts its own status line back
([Enable the Claude quota](./enable-claude-quota.md)).

A problem about a status line names the account: "Claude · work · Another status line is in use".

## A folder nobody named

Every ten minutes, with the other checks, the app looks at the hidden folders at the top of your home (`~/.claude-work`,
`~/.codex-personal`, never deeper) and at the two default folders. A folder that holds what a tool leaves in one (`.claude.json`
and `projects/` for Claude Code, `auth.json` and `config.toml` for the Codex CLI) and that no entry's `home` names becomes a
problem in the panel: _A Claude Code folder is not in providers.json_, with the folder and who is signed in there. **Add it**
opens the sheet of Settings, filled in; **Dismiss** hides it until the folder changes. A folder elsewhere is added with
**Choose…**, or by hand.

## By hand

An account is an entry like the others, with a `home`. The quickest way is to copy the tool's entry, give it an id (letters,
digits, `.`, `_` and `-`; it names the files the app keeps for the account), a title and the folder, and move every path of the
default folder to the new one:

```json
{
  "id": "claude-work",
  "title": "Claude · work",
  "home": "~/.claude-work",
  "windows": [300, 10080],
  "integration": "claude-status-line",
  "log": { "root": "~/.claude-work/projects", "…": "…" },
  "quota": { "file": "~/.tokenmeter/claude-work-statusline.json", "…": "…" },
  "plan": { "file": "~/.claude-work/.claude.json", "…": "…" }
}
```

`home` serves the status line, `/usage` and the folder check; the other paths of the entry are read as written, with `~` your
home. The sheet writes exactly this, so **Add an account…** is the surer way ([Configure providers](./configure-providers.md)).

## What it does not do

It does not read your shell's configuration, the Keychain or the environment of other processes, so a folder named only by
`CLAUDE_CONFIG_DIR` in your shell is found only if it sits at the top of your home. It cannot tell apart two logins that took turns
in the same folder: their history is one.

## Related

- [Configure providers](./configure-providers.md)
- [Enable the Claude quota](./enable-claude-quota.md)
- [Settings](./settings.md)
