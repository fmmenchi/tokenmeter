---
title: Accounts
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-03
---

# Accounts

Several accounts of the same tool, a work one and a personal one, each with its own card. An account is a configuration
folder of Claude Code or of the Codex CLI, and a provider entry names it; everything the app already does for a provider, the
quota, the plan, the history, the notices and the status line, it does for that folder.

|        |            |
| :----- | :--------- |
| Date   | 2026-11-03 |
| Status | in design  |

## Intent

Claude Code and the Codex CLI keep one login per configuration folder (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`), and people with a
work and a personal account already use two folders. Today tokenmeter reads one home for every provider, so the second account
is invisible, and its status line and its `/usage` are never set up.

The app does not learn a new concept: an account is a provider like the others, with its own id and title, which is what
keeps the history, the preferences and the notices apart with no change to them. What the app adds is the folder an entry
reads from, the setup of that folder's status line, the email the folder is signed in with, a tab to add, rename and remove
accounts, a lock on the panel to arrange their cards, and a word, with a button, when it finds a folder nobody named.

## The nucleus

| Part                | Page                                              | Status |
| :------------------ | :------------------------------------------------ | :----- |
| Proposal            | [Proposal](./proposal.md)                         | chosen |
| Implementation plan | not yet written                                   |        |
| Decisions           | ADR 0014, the home of a provider, not yet written |        |

## Related

- [Configure providers](../../use/configure-providers.md): the file an account is an entry of
- [Enable the Claude quota](../../use/enable-claude-quota.md): the status line that each account gets
- [Alerts with a fix](../2026-10-30-alerts-with-a-fix/index.md): the problem that says a folder was found
- [Welcome tour](../2026-11-03-welcome-tour/index.md): the page the accounts add to it
