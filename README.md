# tokenmeter

A macOS menu-bar app and widget showing how much of your **Claude** and **ChatGPT** plan quota is left.

![The menu-bar panel with a 5-hour and a weekly bar per provider](./docs/assets/panel.png)

**Documentation: <https://fmmenchi.github.io/tokenmeter/>**

## Quick start

You need macOS 14 or later, Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and an Apple signing team. Set your team once, then install:

```sh
cp Local.xcconfig.example Local.xcconfig   # put your team ID in it
./scripts/install.sh                       # builds, installs in /Applications, sets up the Claude status line
```

It reads only files Claude Code and the Codex CLI leave on your machine: no credentials, no network.

## Where to go next

| I want to…                            | Read                                                                                     |
| :------------------------------------ | :--------------------------------------------------------------------------------------- |
| install it and keep it running        | [Install and Run](https://fmmenchi.github.io/tokenmeter/develop/build-and-run)           |
| see the Claude quota                  | [Enable the Claude Quota](https://fmmenchi.github.io/tokenmeter/use/enable-claude-quota) |
| understand a bar, a colour or the `~` | [Reading the Bars](https://fmmenchi.github.io/tokenmeter/use/bars)                       |
| add another AI tool from a JSON file  | [Configure Providers](https://fmmenchi.github.io/tokenmeter/use/configure-providers)     |
| know why it works this way            | [Decisions (ADRs)](https://fmmenchi.github.io/tokenmeter/adr)                            |

The same pages are the Markdown files in [`docs/`](./docs); `pnpm install && pnpm run docs:start` serves them locally.

## Working on it

`pnpm run check` is the gate (formatting, `swift test`, the helper scripts' tests and the docs build). [AGENTS.md](./AGENTS.md) says how changes are made.
