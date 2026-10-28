# Architecture — agent rules

Where things go. The decisions behind them are in `docs/adr/`.

| Path                        | What                                                                            |
| --------------------------- | ------------------------------------------------------------------------------- |
| `Sources/TokenMeterCore`    | Log readers, window aggregation, `Snapshot`. No UI, no I/O beyond reading logs. |
| `Sources/tokenmeter-probe`  | Terminal spike printing per-window usage. Not a product surface.                |
| `Tests/TokenMeterCoreTests` | XCTest; fixtures are written to a temp dir, never to real logs.                 |
| `docs/`                     | Markdown docs and ADRs, also the Docusaurus content root.                       |
| `apps/docusaurus`           | The docs site. Content lives in `docs/`, not here.                              |
| `tools/commit`              | Commit-type vocabulary shared by commitlint and the branch gate.                |

Rules:

- The widget extension only renders a `Snapshot`; collection lives in the host app (ADR 0001).
- A remaining-quota figure must carry its `source` (`reported`, `estimated`, `consumptionOnly`).
  Never show a percentage the code cannot attribute to a provider log or a user-set limit.
- Provider log formats are not contracts. Decode tolerantly (optional fields, skip bad lines)
  and add a test with the exact shape that broke.
