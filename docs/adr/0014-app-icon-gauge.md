# ADR 0014 — The app icon is a gauge

Status: accepted (2026-10-28)

## Context

The app had the default icon. Four candidates were drawn (gauge, bars, rings, levels) and Fabio
picked the gauge.

## Decision

The icon is a dark rounded square with a dial: a green, orange and red arc and a white needle. The
arc colours repeat the thresholds of the bars ([Bars](../use/bars.md)). It is the
`AppIcon` set in `App/TokenMeter/Assets.xcassets`, wired by `ASSETCATALOG_COMPILER_APPICON_NAME` in
`project.yml`.

The master is drawn in SwiftUI by `tools/icon/main.swift` (`swift tools/icon/main.swift out.png`)
and scaled with `sips` to the sizes the set needs; the PNGs are committed, so a build needs no
extra step.

The menu-bar item draws the same gauge (`App/TokenMeter/MenuBarIcon.swift`) as a monochrome template
image: a dim track, a full arc to 68%, the needle and the hub. It follows the light and dark menu
bar, which a coloured icon would not. It first used the SF Symbol `gauge.with.dots.needle.50percent`;
that looked unrelated to the app icon, so it was replaced.

## Consequences

- Changing the icon means editing the generator, rendering and re-scaling the PNGs.
- The widget has no icon of its own; it takes the app's in the widget gallery.
