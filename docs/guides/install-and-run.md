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

## Step 4: Install it and let it start at login

To keep the app after cleaning the build folder, build the zip ([Package and
Distribute](./package-and-distribute.md)) and copy the app to `/Applications`:

```bash
./scripts/package.sh
ditto -x -k dist/TokenMeter-*.zip /tmp/tokenmeter
ditto /tmp/tokenmeter/TokenMeter.app /Applications/TokenMeter.app
open /Applications/TokenMeter.app
```

The app **registers itself to start at login the first time it runs**
([ADR 0011](../adr/0011-launch-at-login.md)). You will see it under System Settings, General, Login
Items. **Settings…** in the panel has a **Launch at login** switch; if you turn it off the app never turns it back
on. Run the copy in `/Applications`: the registration belongs to the copy that registered it.

:::info[Verified]
The zip's app, copied to `/Applications`, starts from there with a valid signature and the widget
registered at that path.
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
