---
sidebar_position: 2
---

# Architecture

```
~/.claude/projects/**.jsonl ─┐
                             ├─► TokenMeterCore ─► Snapshot (JSON, App Group) ─► Widget (WidgetKit)
~/.codex/sessions/**.jsonl ──┘         ▲                                          Menu bar (MenuBarExtra)
                                       └── host app refreshes on a timer
```

- **TokenMeterCore** (Swift package): log readers, window aggregation, `Snapshot`.
- **Host app** (`App/TokenMeter`): menu-bar only, not sandboxed; refreshes every 60 s, writes the
  snapshot to the App Group container and reloads WidgetKit timelines (ADR 0003).
- **Widget extension** (`Widget/TokenMeterWidget`): sandboxed; renders the latest snapshot only.
- **Shared** (`Shared/`): SwiftUI rows compiled into both targets.
- Log readers scan incrementally per file (ADR 0004).

## Window semantics

| Source     | Window | Quota                                                      |
| ---------- | ------ | ---------------------------------------------------------- |
| Codex logs | 5h, 7d | `reported` when `rate_limits` primary/secondary is present |
| Claude     | 5h, 7d | `reported` from the status line (ADR 0005), else none      |

Token totals include cache reads, which dominate the count; they measure traffic, not plan cost.
