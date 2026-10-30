---
title: Alerts with a fix, implementation plan
sidebar_label: Implementation plan
sidebar_position: 3
---

# Alerts with a fix, implementation plan

How the app will detect problems, show them and fix them, and the order in which it gets built. Nothing here is
written yet: the decisions are [ADR 0030](../../adr/0030-problems-with-a-topic-and-a-fix.md) (what a problem is, how it
shows and what its actions do) and [ADR 0031](../../adr/0031-problems-come-from-the-app-and-from-provider-integrations.md)
(where the code lives). This page is the map from them to commits.

## Intent

A problem has a topic (a provider or `general`), a message and, sometimes, a fix. The app finds them, the widget, the
menu bar and the panel show them, and the panel can run a fix. Each provider can have problems and fixes of its own,
and the common code never names a provider.

## The pieces

```mermaid
flowchart LR
  CFG[/"providers.json<br/>optional field: integration"/]

  subgraph Core["TokenMeterCore: no UI"]
    MODEL["Problem and Fix model"]
    DET["ProblemDetector"]
    APPP["AppProblems<br/>(the general ones)"]
    PROTO["ProviderIntegration<br/>(protocol)"]
    REG["Integrations registry"]
    RUN["FixRunner"]
    DIS["Dismissals"]
    SNAP["Snapshot.problems"]
  end

  subgraph Plug["Integrations: one per provider that needs one"]
    CLAUDE["ClaudeIntegration<br/>wraps ClaudeStatusLine<br/>and ProjectStatusLines"]
    LATER["a future provider"]
  end

  subgraph App["App"]
    METER["Meter<br/>orchestrates only"]
    PANEL["Panel: banners"]
    BAR["Menu bar: chip with the total"]
  end

  CHIP["Shared: NoticeChip"]
  WIDGET["Widget: chip per provider"]

  CFG --> REG
  REG --> PROTO
  CLAUDE -. implements .-> PROTO
  LATER -. implements .-> PROTO
  DET --> APPP
  DET --> PROTO
  DET --> MODEL
  METER --> DET
  METER --> DIS
  METER --> SNAP
  SNAP --> WIDGET
  METER --> PANEL
  METER --> BAR
  PANEL --> RUN
  RUN --> PROTO
  CHIP --- WIDGET
  CHIP --- BAR
  CHIP --- PANEL
```

The arrows go one way: sources of problems, then the detector, then the snapshot, then the surfaces. A surface never
asks a check anything, and a check never knows a surface exists.

## Files

```text
Sources/TokenMeterCore/Problems/
  Problem.swift             the model: Problem, Fix descriptor, Topic
  ProblemDetector.swift     runs the sources, drops duplicates by id, orders them
  AppProblems.swift         the checks of the app itself (topic general)
  ProviderIntegration.swift the protocol and the descriptor of a fix
  Integrations.swift        id to implementation, one line each
  ClaudeIntegration.swift   the first integration
  FixRunner.swift           runs a fix through the integration that declared it
  Dismissals.swift          what was hidden, behind a protocol
Sources/TokenMeterCore/Snapshot.swift        gains `problems`
Sources/TokenMeterCore/ProviderConfig.swift  gains `integration`
App/TokenMeter/Meter.swift                   orchestrates, keeps the state of each fix
App/TokenMeter/ProblemBanner.swift           the panel's banners
Shared/NoticeChip.swift                      the chip of widget, menu bar and panel
Tests/TokenMeterCoreTests/Problems*Tests.swift  one file of tests per module
```

## The model

```mermaid
classDiagram
  class Problem {
    +String id
    +String topic
    +String message
    +String? detail
    +String? fix
    +String? guide
  }
  class FixDescriptor {
    +String id
    +String label
    +String explanation
  }
  class ProviderIntegration {
    <<protocol>>
    +String id
    +problems(context) Problem[]
    +fixes FixDescriptor[]
    +run(fixId, context) FixResult
  }
  class ClaudeIntegration
  class ProblemDetector {
    +detect(config, context) Problem[]
  }
  class Dismissals {
    <<protocol>>
    +isHidden(problem) Bool
    +hide(problem)
  }
  class FixRunner {
    +run(problem) FixResult
  }
  ProviderIntegration <|.. ClaudeIntegration
  ProviderIntegration --> FixDescriptor : declares
  ProviderIntegration --> Problem : reports
  ProblemDetector ..> ProviderIntegration : asks each
  FixRunner ..> ProviderIntegration : runs a fix on
  Problem ..> FixDescriptor : fix is its id
```

A problem's `fix` is only the id of a fix its provider's integration declared. The label of the button and the text of
**Learn more** come from that descriptor, so the interface knows nothing about what a fix means. `topic` is a provider
id or `general`; ids are written `<topic>.<check>[.<detail>]` and stay the same from one check to the next, because
Dismiss depends on them.

## A check cycle

```mermaid
sequenceDiagram
  participant M as Meter
  participant D as ProblemDetector
  participant A as AppProblems
  participant I as Integration of a provider
  participant X as Dismissals
  participant S as SnapshotStore
  participant W as Widget

  M->>D: detect, at launch and every 10 minutes
  D->>A: the problems of the app
  A-->>D: general problems
  loop each configured provider with an integration
    D->>I: problems(context)
    I-->>D: the provider's problems
  end
  D-->>M: all problems, no duplicates, ordered
  M->>X: which are hidden?
  X-->>M: the visible ones
  M->>S: write the snapshot with problems
  S-->>W: reads the snapshot
```

The detector runs in the background at utility priority; `general` problems come first, then providers in the order of
`providers.json`. An unknown `integration` id is a `general` problem, not a crash.

## Running a fix

```mermaid
sequenceDiagram
  actor U as You
  participant B as Panel banner
  participant M as Meter
  participant R as FixRunner
  participant I as Integration
  participant D as ProblemDetector

  U->>B: clicks Wrap it
  B->>M: run the fix of this problem
  M->>M: state of the fix: running
  M->>R: run(problem)
  R->>I: run(fixId, context)
  alt it worked
    I-->>R: done
    R-->>M: done
    M->>D: check again
    M->>M: state: done, then the banner goes
  else it failed
    I-->>R: failed(reason)
    R-->>M: failed(reason)
    M->>M: state: failed, the reason replaces the detail
  end
```

```mermaid
stateDiagram-v2
  [*] --> Ready
  Ready --> Running: the fix is clicked
  Running --> Done: the integration answers done
  Running --> Failed: the integration answers failed
  Failed --> Running: Try again
  Done --> [*]: the next check no longer finds it
```

The state of a fix is interface state. It lives in `Meter` and is not in the model or in the snapshot.

## The order of work

```mermaid
flowchart TD
  S1["1. Problem model<br/>and its tests"]
  S2["2. Detector and AppProblems<br/>and their tests"]
  S3["3. Integration protocol, registry<br/>and providers.json field"]
  S4["4. ClaudeIntegration<br/>(wraps what exists)"]
  S5["5. FixRunner and Dismissals"]
  S6["6. Snapshot.problems<br/>with compatibility"]
  S7["7. Meter: schedule, filter,<br/>state of each fix"]
  S8["8. Surfaces: NoticeChip,<br/>banners, menu bar, widget"]
  S9["9. Docs"]
  S10["10. Close: design-export<br/>(Views and Design System),<br/>delete the proposal"]
  S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7 --> S8 --> S9 --> S10
```

| Step | Adds                                                                      | Tests that show it works                                          | Gate                                          |
| :--- | :------------------------------------------------------------------------ | :---------------------------------------------------------------- | :-------------------------------------------- |
| 1    | `Problem.swift`                                                           | encode and decode, a missing `fix`, an unknown topic              | `pnpm run check`                              |
| 2    | `ProblemDetector.swift`, `AppProblems.swift`                              | duplicates dropped, order, an unknown integration id              | `pnpm run check`                              |
| 3    | `ProviderIntegration.swift`, `Integrations.swift`, `ProviderConfig.swift` | an integration found by id, an older config still decodes         | `pnpm run check`                              |
| 4    | `ClaudeIntegration.swift`                                                 | each problem on a throwaway home, the fix leaves the problem gone | `pnpm run check`                              |
| 5    | `FixRunner.swift`, `Dismissals.swift`                                     | done and failed, hidden until the message changes                 | `pnpm run check`                              |
| 6    | `Snapshot.swift`                                                          | an older snapshot reads as having no problems                     | `pnpm run check`                              |
| 7    | `Meter.swift`                                                             | built, the schedule and the state of a fix by hand                | `pnpm run check` and `xcodebuild`             |
| 8    | `NoticeChip.swift`, `ProblemBanner.swift`, the widget and the menu bar    | built, then looked at on screen                                   | `pnpm run check`, `xcodebuild` and the screen |
| 9    | the docs: commands, Core API, troubleshooting                             | the docs build                                                    | `pnpm run check`                              |
| 10   | the Views and the Design System artifacts, the feature's status           | the Views canvas shows the new screens, as built                  | proposal canvas deleted when Fabio asks       |

Steps 1 to 9 are one commit each, three files at most, and leave the gate green. Step 10 is the close: `design-export`
refreshes the Views canvas and the Design System with the screens as built (with a fresh screenshot), the status
becomes _Implemented_, and the proposal canvas is deleted when Fabio asks. Steps 7 and 8 are the only ones the gate does
not build, so they are built with `xcodebuild` and looked at.

## Rules that keep it modular

| Rule                                                       | Why                                                  |
| :--------------------------------------------------------- | :--------------------------------------------------- |
| A source of problems is one file and knows no other.       | Adding one touches one file and one line.            |
| A fix is the descriptor and the action of one integration. | The interface never learns what a fix means.         |
| Ids are stable and follow `<topic>.<check>[.<detail>]`.    | Dismiss is keyed by id.                              |
| `Meter` orchestrates; it holds no check.                   | It does not turn into a catch-all.                   |
| The widget reads `Snapshot.problems` and computes nothing. | The widget stays a drawing of a snapshot (ADR 0001). |
| The common code names no provider; an integration may.     | The same rule as ADR 0015 to 0018.                   |

## Open

The open points of ADR 0030 are settled before the code that needs them: how long Dismiss lasts (before step 5), whether
**Restore original** stays in Settings, and whether the `general` problems are counted in the widget (both before
step 8).

## Related

- [Proposal](./proposal.md) and [overview](./index.md)
- [Architecture](../../develop/architecture.md) and [Core API](../../develop/core-api.md)
- [Add a Provider](../../develop/add-a-provider.md): the integration is an extension of it
- [ADR 0030](../../adr/0030-problems-with-a-topic-and-a-fix.md) and [ADR 0031](../../adr/0031-problems-come-from-the-app-and-from-provider-integrations.md)
