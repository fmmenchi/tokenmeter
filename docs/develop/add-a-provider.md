---
title: Add a Provider
sidebar_label: Add a Provider
sidebar_position: 6
---

# Add a Provider

Teach tokenmeter to read another AI tool. If its logs fit a JSON description,
[Configure Providers](../use/configure-providers.md) needs no Swift at all; this guide is for the ones that
do not.

## Intent

Show a third provider next to Claude and ChatGPT without touching the window maths, the bars or
the panel. The split is in [ADR 0015](../adr/0015-provider-contract.md): the app owns what is the
same for everyone, and a provider declares only what is its own.

## Prerequisites

- The tool leaves usage on disk (token counts with a time). Without that there is nothing to read.
- Optionally, a quota the tool reports (a used percentage and a reset time per window).

## Step 1: Write the source

Add a type that implements `ProviderSource` in `Sources/TokenMeterCore`:

```swift
public struct GeminiSource: ProviderSource {
    public let info = ProviderInfo(
        provider: Provider(rawValue: "gemini"), title: "Gemini", windows: [.session, .week],
        setupHint: nil)

    public func read(since: Date) -> ProviderReading {
        ProviderReading(events: [...], quotas: [...], plan: nil, quotaUpdatedAt: nil)
    }
}
```

`info` holds what never changes: id, display name, the windows, and an optional hint shown while no
quota has been seen. `read(since:)` returns what the files say now. How it finds and parses them is
the source's own business.

## Step 2: List it

Append the source to the list `Providers.standard()` builds in `Sources/TokenMeterCore/Providers.swift`.
That is the only place providers are assembled: `Collector`, the probe and the panel iterate it.

## Step 3: Test and check

Write a fixture with the exact shape of the tool's logs in a temp directory and test the source
against it, as the provider tests do. Then run the gate and the probe:

```bash
pnpm run check
swift run tokenmeter-probe
```

The probe prints each provider's windows from the same `Collector` the app uses.

## Step 4 (optional): Report its problems

A provider that needs something set up, such as Claude's status line, can report problems and offer a fix. Implement
`ProviderIntegration` in `Sources/TokenMeterCore/Problems/`: declare each `ProblemKind` it can report (topic,
summary, explanation, guide, fix), report them in `problems(in:)`, and run its fixes in `run(fix:in:)`. Register it
with one line in the list the app passes to `Integrations`, and name it in the provider's `integration` field in
`providers.json`. The detector, the panel and the widget do not change
([ADR 0031](../adr/0031-problems-come-from-the-app-and-from-provider-integrations.md)). Test it on a throwaway home
folder, as `ClaudeIntegrationTests` does.

## Related

- [Data Sources](./data-sources.md)
- [Contribute](./contribute.md)
