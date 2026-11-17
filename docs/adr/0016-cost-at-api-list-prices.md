# ADR 0016 — Cost at API list prices: a dated list in the app, the caches counted, nothing guessed

Status: accepted (2026-11-16)

## Context

The stats count the tokens of each model, input plus output, from the CLIs' logs ([ADR 0010](./0010-the-usage-store.md)). Other local
tools show what those tokens would cost in dollars, and the author asked for it. A plan is not billed by the token, so the figure is an
estimate of what the same use would cost through the API; it needs a price for each model, which no file on the Mac holds.

## Decision

- **The prices are a list in `TokenMeterCore` (`Pricing`), dated (`Pricing.listedOn`)**, taken from the provider's first-party API
  price table. No price is fetched: the app makes no network call for it, as for everything else it shows.
- **A model is priced by the longest listed name its log name contains**, so a newer model is never read as an older one with a
  shorter name. **A model the list does not name has no cost**: the stats show a dash, and a total that counts only some models says so.
  Today the list holds Anthropic's models only; OpenAI's show no cost until they are added.
- **The cost counts the caches**: input, output, cache writes (at 1.25 times the input, the five-minute write) and cache reads (the
  listed price, else a tenth of the input). The store already keeps both, and leaving them out would understate the cost many times.
  The token figures keep leaving them out, as before.
- **It is always written "≈ $" and named "at API list prices"**, in the stats only. The panel's quota view does not show it.

## Consequences

- The list goes stale when prices change or a model is released: each release should check it, and its date says how old it is.
- An old message is priced at today's list, not at the price of its day.
- The cost is only this Mac's tokens, like every token figure of the stats.
