# ADR 0008 — Signing and distribution: a Developer ID build, notarized, outside the App Store

Status: accepted (2026-10-28, consolidated 2026-11-02 from the ADRs on distributing a prebuilt app, bundle identifiers and notarization)

## Context

Building needs Xcode, XcodeGen and a signing team, and someone who only wants the app should not. The app is not sandboxed
([ADR 0001](./0001-app-architecture.md)), so it ships outside the Mac App Store, and the widget needs an App Group, so it needs a team.

## Decision

- **Ship a zip of the Release build** produced by `scripts/package.sh`. Unsigned or ad-hoc builds are not offered. A Personal Team build
  runs only on the Mac that built it, so distribution uses the paid team and a **Developer ID Application** certificate.
- **Bundle identifiers**, chosen once and kept: the app `com.fmmenchi.tokenmeter.app`, the widget `com.fmmenchi.tokenmeter.app.widget`
  (it keeps the app's as its prefix, which an embedded extension requires). The identifiers the Personal Team had registered cannot be
  registered by another team.
- **Two scripts**, so that signing can be checked without notarization credentials: `scripts/sign-release.sh` archives and exports with
  the `developer-id` method and writes `dist/TokenMeter-<version>.zip`; `scripts/notarize.sh` submits it with `xcrun notarytool submit
--wait`, staples the ticket, zips again and runs `spctl --assess`, and stops on a rejection printing Apple's log. The team ID comes
  from `Local.xcconfig`, as for every build. The Hardened Runtime is on for the app and the widget.
- **Credentials are never in the repository or in a script**: `notarize.sh` uses a keychain profile, `tokenmeter-notary`, created once
  with `xcrun notarytool store-credentials`. `scripts/install.sh` keeps using the development build, the fast loop that needs no network.
  A GitHub release workflow is written only once the secrets exist.

## Consequences

- Only the stapled zip from `notarize.sh` opens with a double click on any Mac; `dist/` is git-ignored.
- Settings kept under the old identifiers start fresh, and the old login item must be removed.
- Notarization needs the network and takes minutes, which is why it is not part of `install.sh`.
- The App Group and the widget on the desktop were verified on the author's Mac with the Developer ID build of v0.2.0 (every version since is notarized). Not verified: the double click of the zip on another Mac.
