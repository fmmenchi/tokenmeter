# ADR 0010 — Distribute a prebuilt app

Status: accepted (2026-10-28); notarized distribution deferred

## Context

Building needs Xcode, XcodeGen and a signing team. Someone who only wants the app should not.

## Decision

Ship a zip of the Release build, produced by `scripts/package.sh`. How far it runs depends on the
signature, which is the only thing that changes:

- **Personal Team** (today): runs on the machine that built it. Other Macs refuse it.
- **Developer ID + notarization**: opens with a double click anywhere, and the App Group the widget
  needs works. Not set up: it needs a paid certificate and notarization credentials, and which
  Apple account to use is Fabio's call.
- **Unsigned or ad-hoc**: not offered. The App Group needs a team, so the widget could not work.

The app stays unsandboxed (ADR 0003), so it is distributed outside the Mac App Store.

A release workflow is added only once the signing secrets exist, so that it can be tested.

## Consequences

- `dist/` is git-ignored; the zip is an artifact, not a source file.
- Until Developer ID exists, "download and open" works for the person who built it only.
