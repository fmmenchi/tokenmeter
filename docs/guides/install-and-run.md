---
title: Install and Run
sidebar_label: Install and Run
sidebar_position: 1
---

# Install and Run

Build the app, give it a signing team and keep it running in the menu bar.

## Intent

Go from a clean checkout to a gauge icon in the menu bar whose panel shows your bars. Turning on
the Claude quota and the desktop widget are the next two guides.

## Prerequisites

- macOS 14 or later, and Xcode with the Swift 6 toolchain.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- An Apple signing team. The widget reads the snapshot through an App Group, and an App Group
  needs a team ([ADR 0003](../adr/0003-host-app-widget-and-app-group.md)). A free Personal Team
  was enough on the machine this was built on.
- Claude Code and/or the Codex CLI: both providers are read from what those tools leave on disk.

## Step 1: Set your team

```bash
cp Local.xcconfig.example Local.xcconfig
```

Open `Local.xcconfig` (git-ignored) and replace `XXXXXXXXXX` with your team ID. It is listed under
Xcode, Settings, Accounts, or by `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`.

## Step 2: Generate the project and build

```bash
xcodegen generate
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Debug \
  -derivedDataPath .build/xcode -allowProvisioningUpdates build
```

The `.xcodeproj` is generated from `project.yml` and is not committed. Run `xcodegen generate`
again after adding or removing source files.

## Step 3: Run it

```bash
open .build/xcode/Build/Products/Debug/TokenMeter.app
```

The app has no Dock icon and no window: look for the gauge icon in the menu bar and click it to
open the panel. Without a team the app still runs, but the panel warns that the widget cannot read
the snapshot.

## Step 4: Keep it running

The app does not start at login. Add it under **System Settings, General, Login Items**.

:::caution[Not tested]
Copying `TokenMeter.app` to `/Applications` before adding it to Login Items, so it survives
cleaning the build folder, was not tried here. Only running it from the build folder was.
:::

## Check from the terminal

```bash
swift run tokenmeter-probe
```

Prints each provider's 5h and 7d window with its tokens and remaining quota. If the probe shows the
numbers you expect and the panel does not, the problem is in the app, not in the data.

## Related

- [Enable the Claude Quota](./enable-claude-quota.md)
- [Add the Widget](./add-the-widget.md)
- [Troubleshooting](./troubleshooting.md)
