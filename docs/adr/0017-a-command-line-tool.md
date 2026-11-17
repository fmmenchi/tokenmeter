# ADR 0017 — A command-line tool that reads what the app already keeps

Status: accepted (2026-11-16)

## Context

The quota and the stats are seen in the panel and the widget only. Scripts, a terminal status line or another tool cannot read them;
the local tools tokenmeter is compared with all have a command that prints the figures, often as JSON. The app already keeps
everything such a command needs: the snapshot it writes for the widget ([ADR 0001](./0001-app-architecture.md)) and the usage store
([ADR 0010](./0010-the-usage-store.md)).

## Decision

- **A second executable, `tokenmeter`, ships inside the app bundle** (`TokenMeter.app/Contents/MacOS/tokenmeter`), built from a new
  Swift package target that depends on `TokenMeterCore` and on nothing else. It is signed and notarized with the app, and updated
  with it by Sparkle ([ADR 0011](./0011-updates.md)).
- **It reads, it never collects.** The quota comes from the snapshot the app wrote for the widget, at the App Group container's path;
  the stats and the cost from `usage.sqlite`, opened read-only. It reads no log, runs no Claude Code, and makes no network call, so it
  says exactly what the panel says and adds no second reader of the CLIs' files.
- **The app must have run.** Without a snapshot the tool says so and exits 1; with one older than 10 minutes it prints it with its age
  and exits 2, so a script can tell a stale figure from a fresh one. 0 is a fresh reading.
- **The JSON is a contract with a version** (`"version": 1`): fields are added, never renamed or removed, within a version.
- **It reads the app's own preferences** (the left or used reading, ADR 0006) from the app's defaults domain, and `--left` / `--used`
  override them.
- **Installing it on the `PATH` is the person's step**: Settings › General shows the path and a button that copies the `ln -s` command
  into `/usr/local/bin`. The app never writes outside its container and asks for no administrator password.

## Consequences

- The tool is only as fresh as the app: it shows the last refresh, not a new one.
- `tokenmeter-probe` stays a development spike, not shipped.
- The bundle gains a second signed executable, which the release scripts must sign with the hardened runtime like the app.
