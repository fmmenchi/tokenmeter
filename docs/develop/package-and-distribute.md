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
([ADR 0008](../adr/0008-signing-and-distribution.md)).

## Step 1: Build the zip

```bash
./scripts/package.sh
```

It generates the project, builds the Release app, and writes `dist/TokenMeter-<version>.zip`
(`dist/` is git-ignored), then prints the checksum and the signing team.

## Step 2: Know what the signature allows

| Signed with                      | Runs on                                    | Widget                                                      |
| :------------------------------- | :----------------------------------------- | :---------------------------------------------------------- |
| Personal Team (the default here) | The Mac that built it. Others get blocked. | Needs the App Group.                                        |
| Developer ID, notarized          | Any Mac, with a double click.              | Seen working on the author's Mac; not tried on another Mac. |

The zip that `install.sh` and `package.sh` build is signed with a development certificate and Gatekeeper rejects it
(`spctl -a -vv` says `rejected`), so it is not something to hand to someone else: the release is made in step 3.

## Step 3: Sign for other Macs and notarize

This needs the paid Apple Developer Program, a `Developer ID Application` certificate in your login
keychain (Xcode → Settings → Accounts → Manage Certificates) and notarization credentials
([ADR 0008](../adr/0008-signing-and-distribution.md)). Store the credentials once; the
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
`Unnotarized Developer ID`. Only the zip left by `notarize.sh` opens with a double click anywhere. Both scripts zip with
`ditto --norsrc`, so the archive has no `._` entries: with them, a third-party unarchiver leaves `._` files in the bundle, the
seal breaks and Gatekeeper says it cannot verify the app.
A release workflow in CI is not written until the same credentials exist as repository secrets.

To build, install and set up the status line in one go, use `./scripts/install.sh`
([Install and Run](./build-and-run.md)).

## Step 4: Publish a version the app can update to

The app looks once a day for `appcast.xml`, attached to the latest release, and installs what it finds when the user agrees
([ADR 0011](../adr/0011-updates.md)). Updates are signed with a key that only you have.

**Once**, make the key. Run it yourself, in a terminal: it keeps the private half in your login keychain and prints the public
half, and the private half is never pasted into a chat, a script or the repository.

```bash
.build/xcode/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
.build/xcode/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x ~/tokenmeter-update-key   # a copy: put it in a password manager, then delete the file
```

Put the public key it printed in `project.yml` as `SU_PUBLIC_ED_KEY` and commit it. Until it is there, `sign-release.sh` and
`appcast.sh` refuse and a build does not look for updates. The key is in the base settings of the app, so every build made from
this repository, a Debug one included, has it and asks GitHub once a day; only a build whose key is removed does not. If the key is lost, no installed copy can update itself and people
download the app again, so the copy matters.

**For each release**, after the steps above:

```bash
# 1. raise CURRENT_PROJECT_VERSION by one, set MARKETING_VERSION, write the version in docs/use/changelog.md and make its page of notes:
./scripts/release-notes.sh  #    apps/docusaurus/static/release-notes/v<version>.html; commit all of it, then tag v<MARKETING_VERSION>
./scripts/sign-release.sh   # refuses without the key or the tag
./scripts/notarize.sh       # the signature below is of this final zip
./scripts/appcast.sh        # writes dist/appcast.xml, refuses a build number that does not go up
```

Push `main` first, so that the docs site serves the page of notes the feed points to (`/release-notes/v<version>.html`, a clean page
made from [the changelog](../use/changelog.md), which is where the notes are written), then publish the release with the zip, its
`.sha256` and `dist/appcast.xml` attached. Pushing and publishing ask first, as notarizing does.

Checked by hand, not by a test, before the first release with the updater: the check from the menu with a click, an update served
from a local feed with the widget on the desktop watched, an update of a build that has a store, the address of the feed as the
redirect of the latest release, and a download with Gatekeeper's quarantine. A release says which of these it did not do.

## Related

- [Install and Run](./build-and-run.md)
- [Contribute](./contribute.md)
