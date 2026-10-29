# ADR 0022 — The docs are split by reader

Status: accepted (2026-10-29)

## Context

`guides/` mixed two readers: someone who only wants the app on the menu bar, and someone who builds,
signs or extends it. A user had to read about XcodeGen and notarization to learn how to read a bar,
and a developer had to look for the architecture across `concepts/`, `reference/` and `.agents/`.

## Decision

Two sections of the site, plus the decisions:

- **Use** (`docs/use/`): what tokenmeter does, what it reads and that it costs nothing, how to
  install it, the Claude quota and the widget, reading the bars, adding a provider from a JSON file,
  and troubleshooting. No Xcode, no Swift.
- **Develop** (`docs/develop/`): the whole picture: build and run, architecture, the public API of
  `TokenMeterCore`, the `providers.json` and snapshot formats, data sources, commands and files,
  adding a provider in Swift, signing and notarization, contributing.
- **Decisions** (`docs/adr/`) stay where they are, because every ADR links to the others.

`docs/guides/` and `docs/reference/` no longer exist. Public URLs change (for example
`/guides/install-and-run` becomes `/develop/build-and-run`); no redirects are added, because the site
was published a few hours ago and nothing outside the README links to it.

## Consequences

- A page belongs to one reader. When a topic serves both (the providers file), the user page says
  how to use it and the developer page says how it is decoded.
- The README and the Overview link to the new addresses.
- The Use install page is only complete once a notarized zip exists ([ADR 0021](./0021-developer-id-signing-and-notarization.md));
  until then it says that installing means building.
