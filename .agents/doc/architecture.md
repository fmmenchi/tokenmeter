# Architecture — agent rules

Where things go. The decisions behind them are in `docs/adr/`.

| Path                        | What                                                                                                                        |
| --------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `Sources/TokenMeterCore`    | Log readers, window aggregation, `Snapshot`, `Problems/`. No UI. It writes only what an integration's fix or ADR 0033 says. |
| `Sources/tokenmeter-probe`  | Terminal spike printing per-window usage. Not a product surface.                                                            |
| `Tests/TokenMeterCoreTests` | XCTest; fixtures are written to a temp dir, never to real logs.                                                             |
| `docs/`                     | Markdown docs and ADRs, also the Docusaurus content root.                                                                   |
| `apps/docusaurus`           | The docs site. Content lives in `docs/`, not here.                                                                          |
| `tools/commit`              | Commit-type vocabulary shared by commitlint and the branch gate.                                                            |

Rules:

- The widget extension only renders a `Snapshot`; collection lives in the host app (ADR 0001).
- Every provider is a `ProviderSource` assembled in `Providers.standard()` (ADR 0015). Claude and
  ChatGPT are two entries of `~/.tokenmeter/providers.json`, which is the only source and which the
  app seeds from `DefaultProviders.swift` on first run (ADR 0016-0018). All entries run as
  `ConfiguredSource`; write Swift only for a log the format cannot say.
  Window maths, bars and refresh are common and never name a provider.
- A remaining-quota figure must carry its `source` (`reported`, `reset`, `consumptionOnly`).
  Never show a percentage the code cannot attribute to a provider log or a reset window (ADR 0007).
- Provider log formats are not contracts. Decode tolerantly (optional fields, skip bad lines)
  and add a test with the exact shape that broke.
- A problem is a `ProblemKind` declared by the app (`AppProblems`) or by one provider's `ProviderIntegration`
  (ADR 0030, 0031, 0033). Add a check there; the detector, panel and widget never name a provider.
