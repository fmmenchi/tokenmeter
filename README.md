# tokenmeter

A macOS widget and menu-bar item showing how much of your Claude and ChatGPT plan quota is left.

**Status:** early. The log-reading core and a terminal probe work; the widget app is not built yet.

```sh
swift test                      # core tests
swift run tokenmeter-probe      # per-window usage from local Claude Code and Codex logs
pnpm install && pnpm run docs:start
```

Quota is shown only when a provider log reports it or you set a limit; otherwise only consumption.
See the [docs](./docs/intro.md), [AGENTS.md](./AGENTS.md) for how we work, and `docs/adr/` for decisions.
