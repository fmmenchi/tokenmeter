---
title: Add a Provider
sidebar_label: Add a Provider
sidebar_position: 7
---

# Add a Provider

Teach tokenmeter to read another AI tool, in one source type and one line.

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

Add the source to `Providers.standard()` in `Sources/TokenMeterCore/Providers.swift`. That list is
the only place providers are named: `Collector`, the probe and the panel iterate it.

## Step 3: Test and check

Write a fixture with the exact shape of the tool's logs in a temp directory and test the source
against it, as the reader tests do. Then run the gate and the probe:

```bash
pnpm run check
swift run tokenmeter-probe
```

The probe prints each provider's windows from the same `Collector` the app uses.

## Related

- [Data Sources](../reference/data-sources.md)
- [Contribute](./contribute.md)
