# ADR 0021 — Developer ID signing and notarization

Status: accepted (2026-10-29)

## Context

[ADR 0010](./0010-distribute-a-prebuilt-app.md) deferred a build that opens on another Mac. The paid
team now exists ([ADR 0020](./0020-bundle-identifiers-under-the-paid-team.md)) and so does a
`Developer ID Application` certificate in the login keychain. Gatekeeper accepts an app from outside
the Mac App Store only if it is signed with that certificate **and** notarized by Apple.

## Decision

Two scripts, so that signing can be checked without notarization credentials:

- `scripts/sign-release.sh` archives the app and exports it with the `developer-id` method (Xcode
  signs it and creates the Developer ID provisioning profile the App Group needs), then writes
  `dist/TokenMeter-<version>.zip`. The team ID comes from `Local.xcconfig`, as for every build.
- `scripts/notarize.sh` submits that zip with `xcrun notarytool submit --wait`, staples the ticket
  to the app, zips it again and runs `spctl --assess` on it. It stops on a rejected submission and
  prints Apple's log.

**Credentials are never in the repository or in a script.** `notarize.sh` uses a keychain profile
named `tokenmeter-notary`, created once by Fabio with `xcrun notarytool store-credentials`, which asks
for an app-specific password in the terminal. A GitHub release workflow comes later, with the same
values as repository secrets that Fabio adds; it is not written until they exist.

`scripts/install.sh` keeps using the development build: it is the fast loop and needs no network.

## Consequences

- The zip from `sign-release.sh` is signed but not yet accepted by Gatekeeper; only the stapled zip
  from `notarize.sh` opens with a double click on any Mac.
- Notarization requires the Hardened Runtime, so `ENABLE_HARDENED_RUNTIME` is on for the app and the
  widget (it was off, `flags=0x0`, and Apple would have rejected the submission).
- Notarization needs the network and takes minutes, which is why it is not part of `install.sh`.
- Whether the App Group works under Developer ID is verified by running the notarized build, not
  assumed; the result goes in the guide.
