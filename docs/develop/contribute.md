---
title: Contribute
sidebar_label: Contribute
sidebar_position: 9
---

# Contribute

How changes are made in this repository: decisions, branches, commits, hooks and CI.

## Intent

Keep the history readable and the gate honest. The rules are the same ones used in the other
repositories of this account, so the habits carry over.

## Step 1: Write the decision down first

A structural decision gets an ADR in `docs/adr/NNNN-title.md` before any code: status line,
context, decision, consequences. If it replaces an earlier one, say which parts it supersedes.
Existing ADRs are in [Decisions](../adr).

## Step 2: Branch

Never work on `main`. A branch is `<type>/<description>`, lowercase words joined by `-`, at least
three characters, for example `feat/launch-at-login`. The type comes from the commit vocabulary
below. The `pre-push` hook enforces it.

## Step 3: Commit

Conventional commits, one concern each. The `commit-msg` hook runs commitlint.

| Type       | Use for                                         |
| :--------- | :---------------------------------------------- |
| `feat`     | A new capability.                               |
| `fix`      | A bug fix.                                      |
| `perf`     | A speed or memory improvement.                  |
| `refactor` | A change with no behaviour change.              |
| `test`     | Tests only.                                     |
| `docs`     | Documentation and ADRs.                         |
| `build`    | Build system, dependencies, project generation. |
| `ci`       | Workflows.                                      |
| `style`    | Formatting only.                                |
| `chore`    | Everything else.                                |
| `revert`   | Reverting a commit.                             |

The list lives in `tools/commit/types.mjs`, shared by commitlint and the branch check.

## Step 4: Run the gate

```bash
pnpm install        # once; also installs the git hooks
pnpm run check
```

`check` is Prettier, `swift test` and the Docusaurus build. The `pre-push` hook runs it too. A
failing gate gets fixed; `--no-verify` is not used.

## What CI runs

| Job       | Runner | Does                                                                                         |
| :-------- | :----- | :------------------------------------------------------------------------------------------- |
| `swift`   | macOS  | `swift build`, `swift test`, then generates the project and builds the app with signing off. |
| `web`     | Ubuntu | Prettier check and the Docusaurus build.                                                     |
| `commits` | Ubuntu | commitlint over the pull request's commits.                                                  |

On `main`, `docs.yml` deploys this site to GitHub Pages when `docs/` or `apps/docusaurus/` change.

## Project layout

| Path                         | What                                                                                                                          |
| :--------------------------- | :---------------------------------------------------------------------------------------------------------------------------- |
| `Sources/TokenMeterCore`     | Readers, window maths, snapshot. No UI.                                                                                       |
| `Tests/TokenMeterCoreTests`  | XCTest; fixtures go to a temp folder, never to real logs.                                                                     |
| `App/`, `Widget/`, `Shared/` | The app, the widget and the views they share.                                                                                 |
| `project.yml`                | XcodeGen definition of the Xcode project.                                                                                     |
| `docs/`                      | This site's content, ADRs included.                                                                                           |
| `apps/docusaurus/`           | The site itself.                                                                                                              |
| `.agents/doc/`               | Rules for AI coding agents working in the repo.                                                                               |
| `.claude/skills/`            | `widget-figma`: keeps the widget and Figma aligned ([ADR 0028](../adr/0028-a-skill-to-keep-the-widget-and-figma-aligned.md)). |

:::tip[Provider log formats are not contracts]
Decode tolerantly: optional fields, skip lines that do not parse, and add a test with the exact
shape that broke.
:::

## Related

- [Troubleshooting](../use/troubleshooting.md)
- [Decisions](../adr)
