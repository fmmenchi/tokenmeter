---
title: Package and Distribute
sidebar_label: Package and Distribute
sidebar_position: 4
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

| Signed with                      | Runs on                                    | Widget                              |
| :------------------------------- | :----------------------------------------- | :---------------------------------- |
| Personal Team (the default here) | The Mac that built it. Others get blocked. | Needs the App Group, not confirmed. |
| Developer ID, notarized          | Any Mac, with a double click.              | Yes, in principle.                  |

The zip built here is signed with a development certificate and Gatekeeper rejects it
(`spctl -a -vv` says `rejected`), so it is not yet something to hand to someone else.

:::caution[Developer ID is not set up]
Opening on any Mac needs a paid Developer ID certificate and notarization credentials. Which Apple
account to use is a decision for the owner of the project. A release workflow is deliberately not
in CI until those secrets exist, because it could not be tested without them.
:::

## Related

- [Install and Run](./install-and-run.md)
- [Contribute](./contribute.md)
