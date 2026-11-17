---
title: Command-line tool, plan
sidebar_label: Plan
sidebar_position: 3
---

# Command-line tool, plan

How the [proposal](./proposal.md) is built, under [ADR 0017](../../adr/0017-a-command-line-tool.md).

## Where each thing goes

| Layer | Folder                         | What                                                                                                    |
| :---- | :----------------------------- | :------------------------------------------------------------------------------------------------------ |
| Core  | `Sources/TokenMeterCore/`      | `CommandOutput`: the text lines and the JSON (version 1) of a snapshot and of the stats, pure functions |
| Tests | `Tests/TokenMeterCoreTests/`   | `CommandOutputTests.swift`: the lines, the JSON keys, the reading, the age and the exit code            |
| Tool  | `Sources/tokenmeter/`          | `main.swift`: the arguments, where the files are, printing, the exit code                               |
| Build | `Package.swift`, `project.yml` | the executable target, and a tool target copied into `Contents/MacOS` of the app                        |
| App   | `App/TokenMeter/`              | the row in Settings › General with the copy button                                                      |
| Docs  | `docs/use/`, `docs/develop/`   | a page "Command line", the release scripts if signing needs it                                          |

## The steps

| Step | Commit                                                                           | Files                                             |
| :--- | :------------------------------------------------------------------------------- | :------------------------------------------------ |
| 1    | `feat(core): the text and the json of a snapshot and of the stats for a command` | `CommandOutput.swift`, `CommandOutputTests.swift` |
| 2    | `feat(cli): the tokenmeter command reads the snapshot and the store`             | `Sources/tokenmeter/main.swift`, `Package.swift`  |
| 3    | `build: the command ships inside the app bundle`                                 | `project.yml`, the release scripts if needed      |
| 4    | `feat(app): settings shows the command and copies its install line`              | the General tab                                   |
| 5    | `docs(use)`: the command-line page; the feature folder, the ADR accepted         | `use/command-line.md`, this folder                |

## Tests

The text of a window in left and in used; a window with no figure; the JSON's keys and its version; the age of a reading and the exit
code at 9 and 11 minutes; the stats JSON with a cost, without one, and partial.

## To verify by hand

`tokenmeter` from the installed app after a release: signed, notarized (`spctl`), on the `PATH` through the copied command, with the
app running and quit.
