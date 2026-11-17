# ADR 0016 — Cost at API list prices: a dated list in the app, the caches counted, nothing guessed

Status: accepted (2026-11-16), amended the same day: the list read from the price pages, OpenAI, long prompts, the one-hour cache write

## Context

The stats count the tokens of each model, input plus output, from the CLIs' logs ([ADR 0010](./0010-the-usage-store.md)). Other local
tools show what those tokens would cost in dollars, and the author asked for it. A plan is not billed by the token, so the figure is an
estimate of what the same use would cost through the API; it needs a price for each model, which no file on the Mac holds.

## Decision

- **The prices are a list in `TokenMeterCore` (`Pricing`), dated (`Pricing.listedOn`)**, read from the providers' own price pages
  (platform.claude.com and developers.openai.com, standard tier). No price is fetched by the app: it makes no network call for it, as
  for everything else it shows.
- **A model is priced by the longest listed name its log name contains**, so a newer model is never read as an older one with a
  shorter name. **A model the list does not name has no cost**: the stats show a dash, and a total that counts only some models says so.
  `codex-auto-review` is not on OpenAI's page and has no cost.
- **The cost counts the caches**: input, output, cache writes and cache reads, each at its listed price. Claude Code writes the
  one-hour cache (99.6% of its writes in the logs of the author's Mac), so an Anthropic cache write is priced at twice the input,
  not at the 1.25 times of the five-minute write; Codex writes none. The token figures keep leaving the caches out, as before.
- **A long prompt pays its own rates**: Haiku 5.5 over 100K prompt tokens, OpenAI's models over 272K. The prompt is the input and both
  caches of one message, so the store splits the totals by size of prompt before adding them up (`UsageStore.costTotals`).
- **It is always written "≈ $" and named "at API list prices"**, in the stats only. The panel's quota view does not show it.

## Consequences

- The list goes stale when prices change or a model is released: each release should check it, and its date says how old it is.
- An old message is priced at today's list, not at the price of its day; a promotional price (gpt-5.6-sol until 2026-11-30)
  stays in the list until it is read again.
- The cost is only this Mac's tokens, like every token figure of the stats.
