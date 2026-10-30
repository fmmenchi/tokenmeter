---
title: Provider cards, implementation plan
sidebar_label: Implementation plan
sidebar_position: 3
---

# Provider cards, implementation plan

How the cards get their order and their windows, and the order in which it is built. The decisions are in
[ADR 0035](../../adr/0035-provider-cards-order-and-windows-are-preferences.md); this page is the map from them to commits.
It builds on [Alerts with a fix](../2026-10-30-alerts-with-a-fix/index.md), whose banners sit above the cards.

## Intent

Preferences say which providers come first and which windows each shows. The app applies them to what it has read, writes
the result in the snapshot, and the panel, the widget and the menu bar draw it. Settings edits them.

## The pieces

```mermaid
flowchart LR
  CFG[/"providers.json<br/>the providers and their windows"/]
  PREF[("App defaults<br/>order, windows per provider")]

  subgraph Core["TokenMeterCore: no UI"]
    DISP["DisplayPreferences<br/>(protocol, in memory and defaults)"]
    APPLY["Snapshot.applying(preferences)<br/>order and filter"]
  end

  subgraph App["App"]
    METER["Meter<br/>keeps the full reading, applies, writes"]
    SET["Settings<br/>list: drag and choose"]
    CARD["Shared: ProviderCard"]
    PANEL["Panel"]
    BAR["Menu bar"]
  end

  WIDGET["Widget"]

  CFG --> METER
  PREF --- DISP
  DISP --> APPLY
  METER --> APPLY
  APPLY --> METER
  SET --> METER
  METER --> PANEL
  METER --> BAR
  METER -- snapshot --> WIDGET
  CARD --- PANEL
  CARD --- WIDGET
```

The arrows go one way: the full reading, then the preferences applied, then the snapshot, then the surfaces. The widget
and the card compute nothing.

## Files

```text
Sources/TokenMeterCore/DisplayPreferences.swift   the protocol, the in-memory and the defaults versions
Sources/TokenMeterCore/Snapshot.swift             gains `applying(_:)`
App/TokenMeter/Meter.swift                        keeps the full reading, the preferences, the setters
App/TokenMeter/SettingsView.swift                 the list with the handle and the choice of windows
Shared/ProviderCard.swift                         the card used by the panel and the widget
App/TokenMeter/DragHandle.swift                   the handle to grab a card, a component of the design system
Shared/UsageViews.swift                           ProviderBlock becomes the card's content
Tests/TokenMeterCoreTests/DisplayPreferencesTests.swift
```

## The model

```mermaid
classDiagram
  class DisplayPreferences {
    <<protocol>>
    +order [String]
    +windows(provider) Set~String~?
    +setOrder([String])
    +setWindows(provider, Set~String~)
  }
  class Snapshot {
    +applying(DisplayPreferences) Snapshot
  }
  DisplayPreferences <|.. MemoryDisplayPreferences
  DisplayPreferences <|.. DefaultsDisplayPreferences
  Snapshot ..> DisplayPreferences : orders and filters by
```

`windows(provider)` is `nil` when nothing was chosen, which means every window. Window names are the ones the provider
declares (`5h`, `7d`, or any other), so a provider with other windows is offered those.

## A refresh

```mermaid
sequenceDiagram
  participant M as Meter
  participant C as Collector
  participant P as DisplayPreferences
  participant S as SnapshotStore
  participant W as Widget

  M->>C: read
  C-->>M: the full snapshot, all providers and windows
  M->>P: order and windows
  P-->>M: the preferences
  M->>M: apply: order the providers, drop hidden windows, keep one
  M->>S: write the result with the problems
  S-->>W: reads the snapshot
```

## The order of work

```mermaid
flowchart TD
  S1["1. DisplayPreferences<br/>and its tests"]
  S2["2. Snapshot.applying<br/>and its tests"]
  S3["3. Meter: full reading,<br/>preferences, setters"]
  S4["4. ProviderCard,<br/>panel and widget"]
  S5["5. Settings: the list"]
  S6["6. Docs"]
  S7["7. Close: design-export<br/>(Views and Design System with a dark theme),<br/>delete the proposal"]
  S1 --> S2 --> S3 --> S4 --> S5 --> S6 --> S7
```

| Step | Adds                                                                                                                                                                           | Tests that show it works                                                                      | Gate                                          |
| :--- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------- | :-------------------------------------------- |
| 1    | `DisplayPreferences.swift`                                                                                                                                                     | order kept and a new provider last, windows nil means all, the defaults version persists      | `pnpm run check`                              |
| 2    | `Snapshot.applying`                                                                                                                                                            | order, a hidden window dropped, one always kept, an unknown provider in the order ignored     | `pnpm run check`                              |
| 3    | `Meter.swift`                                                                                                                                                                  | built; the setters change the snapshot and the menu-bar percentage counts the visible windows | `pnpm run check` and `xcodebuild`             |
| 4    | `ProviderCard.swift`, `UsageViews.swift`, the panel, the widget                                                                                                                | built, then looked at on screen in light and in dark                                          | `pnpm run check`, `xcodebuild` and the screen |
| 5    | `SettingsView.swift`                                                                                                                                                           | built; dragging and the choice looked at on screen                                            | `pnpm run check`, `xcodebuild` and the screen |
| 6    | the docs: Settings guide, Core API                                                                                                                                             | the docs build                                                                                | `pnpm run check`                              |
| 7    | the Views and the Design System (the new components `ProviderCard`, `ProviderListRow` and `DragHandle`, the `card-fill` and handle tokens, a dark theme), the feature's status | the Views show the cards as built; the Design System has a dark theme                         | proposal canvas deleted when Fabio asks       |

Steps 1 to 6 are one commit each, three files at most, and leave the gate green. Steps 3 to 5 are not built by the gate,
so they are built with `xcodebuild` and looked at, in the light and the dark appearance. Step 7 is the close:
`design-export` refreshes the Views and the Design System, the status becomes _Implemented_, and the proposal canvas is
deleted when Fabio asks.

## Rules that keep it modular

| Rule                                                       | Why                                                   |
| :--------------------------------------------------------- | :---------------------------------------------------- |
| Preferences are read and applied in the core, never drawn. | The surfaces stay a drawing of a snapshot (ADR 0001). |
| The common code names no provider and no window.           | The same rule as ADR 0015 to 0018.                    |
| The card uses system colours and their opacities only.     | Light and dark hold without a value for either.       |
| `providers.json` is never written for a preference.        | The file is the user's (ADR 0033).                    |

## Open

- Whether a provider with more than two windows shows its choice as a menu or as a row of segments.
- How the widget shows a card whose windows are all hidden but one: unchanged, a card with one row.

## Related

- [Proposal](./proposal.md) and [overview](./index.md)
- [Architecture](../../develop/architecture.md) and [Core API](../../develop/core-api.md)
- [ADR 0035](../../adr/0035-provider-cards-order-and-windows-are-preferences.md)
