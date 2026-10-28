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
- **Host app** (planned): owns collection, writes the snapshot to the App Group container.
- **Widget extension** (planned): renders the latest snapshot only; WidgetKit cannot run long work.

## Window semantics

| Source     | Window | Quota                                          |
| ---------- | ------ | ---------------------------------------------- |
| Codex logs | 5h, 7d | `reported` when `rate_limits` is present       |
| Claude     | 5h, 7d | `estimated` with a configured limit, else none |

Token totals include cache reads, which dominate the count; they measure traffic, not plan cost.
