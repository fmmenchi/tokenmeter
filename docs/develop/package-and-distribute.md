---
title: Package and Distribute
sidebar_label: Package and Distribute
sidebar_position: 8
---

# Package and Distribute

Turn the build into a zip someone else can download.

## Intent

Building needs Xcode, XcodeGen and a signing team. A prebuilt zip removes that for whoever only
wants the app. How far the zip runs depends on how it was signed
([ADR 0010](../adr/0010-distribute-a-prebuilt-app.md)).

## Step 1: Build the zip

```bash
./scripts/package.sh
```

It generates the project, builds the Release app, and writes `dist/TokenMeter-<version>.zip`
(`dist/` is git-ignored), then prints the checksum and the signing team.

## Step 2: Know what the signature allows

| Signed with                      | Runs on                                    | Widget                                  |
| :------------------------------- | :----------------------------------------- | :-------------------------------------- |
| Personal Team (the default here) | The Mac that built it. Others get blocked. | Needs the App Group, not confirmed.     |
| Developer ID, notarized          | Any Mac, with a double click.              | Not yet confirmed on a notarized build. |

The zip built here is signed with a development certificate and Gatekeeper rejects it
(`spctl -a -vv` says `rejected`), so it is not yet something to hand to someone else.

## Step 3: Sign for other Macs and notarize

This needs the paid Apple Developer Program, a `Developer ID Application` certificate in your login
keychain (Xcode → Settings → Accounts → Manage Certificates) and notarization credentials
([ADR 0021](../adr/0021-developer-id-signing-and-notarization.md)). Store the credentials once; the
command asks for an app-specific password from your Apple account, so nothing is written in a file:

```bash
xcrun notarytool store-credentials tokenmeter-notary
```

Then, for each release:

```bash
./scripts/sign-release.sh   # archive, export signed with Developer ID, zip
./scripts/notarize.sh       # submit to Apple, wait, staple, check with spctl
```

`sign-release.sh` alone gives a zip that is signed but that Gatekeeper still calls
`Unnotarized Developer ID`. Only the zip left by `notarize.sh` opens with a double click anywhere.
A release workflow in CI is not written until the same credentials exist as repository secrets.

To build, install and set up the status line in one go, use `./scripts/install.sh`
([Install and Run](./build-and-run.md)).

## Related

- [Install and Run](./build-and-run.md)
- [Contribute](./contribute.md)
