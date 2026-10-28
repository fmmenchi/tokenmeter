# ADR 0006 — No polling of provider usage endpoints

Status: accepted (2026-10-28)

## Context

The Claude quota comes from the status line (ADR 0005), so it only moves while a Claude Code
session renders. A once-a-minute ping would keep it fresh. The ways to ping are:

1. Call the OAuth usage endpoint with the token Claude Code keeps in the Keychain.
2. Run `claude -p` on a timer to make the status line fire.

## Decision

Neither. (1) means a background app holds a credential and calls an undocumented API; if the
endpoint changes or Anthropic objects, the failure is an account problem, not a broken widget.
(2) spends the quota it is meant to measure, and `-p` does not render the status line anyway.

Instead the app re-reads local files every 60 seconds and on every menu open, and shows how old
the Claude quota is, so a stale bar is labelled rather than silently wrong.

## Consequences

- Claude's bars can lag by as long as no session runs. The reset time still bounds the error:
  after `resets_at` the window falls back to consumption only.
- If Fabio wants the endpoint anyway, it needs its own ADR covering the Keychain access.
