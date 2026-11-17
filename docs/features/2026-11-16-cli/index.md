---
title: Command-line tool
sidebar_label: Overview
sidebar_position: 1
date: 2026-11-16
---

# Command-line tool

A `tokenmeter` command prints the quota and the stats in the terminal, as text or as JSON for scripts.

|        |                                  |
| :----- | :------------------------------- |
| Date   | 2026-11-16                       |
| Status | plan written, waiting for review |

## Intent

The figures are only in the panel and the widget. A script, a terminal status line or another tool cannot read them, and the other
local tools all print theirs. The app already keeps what a command needs; the command only reads it.

## The nucleus

| Part                | Page                                              | Status   |
| :------------------ | :------------------------------------------------ | :------- |
| Proposal            | [Proposal](./proposal.md)                         | approved |
| Implementation plan | [Plan](./plan.md)                                 | written  |
| Decisions           | [ADR 0017](../../adr/0017-a-command-line-tool.md) | proposed |
