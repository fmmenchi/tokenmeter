# ADR 0001 — Stack: SwiftUI, WidgetKit and MenuBarExtra

Status: accepted (2026-10-28, Fabio)

## Context

tokenmeter must be a macOS widget. Desktop and Notification Center widgets are WidgetKit-only.

## Decision

A native SwiftUI app with three parts:

- a host app with a `MenuBarExtra` that owns data collection;
- a WidgetKit extension that only renders;
- a shared Swift package for models and log parsing.

The host app writes a snapshot to an App Group container; the widget reads it. Widgets cannot run
long-lived work, so collection never lives in the extension.

## Consequences

- Requires Xcode and a signing team for the App Group.
- Widget refresh is budgeted by the system; the menu bar item is the live view.
