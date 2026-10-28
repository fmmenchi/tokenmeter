# ADR 0002 — Metric and data sources

Status: proposed (metric accepted by Fabio; sources need verification)

## Context

Fabio uses Claude and ChatGPT on subscription plans. The number that matters is the remaining
quota in each limit window (rolling session, weekly cap), not token counts. Plan limits are not
expressed in tokens and neither provider documents a public API for them.

## Decision

Measure remaining plan quota per provider; show tokens as secondary context where available.
Sources, in order of preference:

1. **Local logs.**
   - Claude Code: `~/.claude/projects/*/*.jsonl`, `usage` objects per message.
     *Verified:* input, output and cache token fields are present.
   - Codex CLI (ChatGPT plan): `~/.codex/sessions/**/rollout-*.jsonl`.
     *Not verified:* `rate_limits` was `null` in every sample checked.
2. **Provider endpoints** only if a spike confirms one is usable without scraping browser cookies.
3. **Rejected:** reading claude.ai / chatgpt.com through browser session cookies (fragile, ToS risk).

## Open questions

- Does any local source expose the remaining-quota percentage for Claude? If not, the widget can
  only show consumed tokens against a user-configured limit, labelled as an estimate.
- Local logs cover only the CLIs, not claude.ai / chatgpt.com web or app usage.

## Next step

A spike (no UI) that prints per-window usage from both log trees, before any widget code.
