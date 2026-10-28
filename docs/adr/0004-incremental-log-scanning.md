# ADR 0004 — Incremental log scanning

Status: accepted (2026-10-28)

## Context

The host app refreshes every 60 seconds. The Claude log tree is 7.5 GB; a full scan of the files
touched in the last 7 days took 31 s in release mode (14 s after skipping non-usage lines before
decoding). That is more than the refresh interval and burns a CPU core.

## Decision

Each reader keeps, per log file, the byte offset it has parsed up to and the events found so far.
A refresh reads only the bytes appended since, and only up to the last complete line. If a file
shrank, its state is discarded and it is re-read. Events older than the 7-day window are pruned.

Readers become reference types guarded by a lock so the cache survives between refreshes.

## Consequences

- The first scan after launch still costs seconds; it runs off the main thread.
- Memory holds one week of events (small: a few numbers per message).
- A log rewritten in place with the same or larger size would be missed. Both CLIs only append.
