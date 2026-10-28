---
sidebar_position: 2
---

# Getting started

From a clean checkout to bars in your menu bar and on the desktop.

## Requirements

- macOS 14 or later, Xcode with the Swift 6 toolchain.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- An Apple signing team. The widget reads the snapshot through an App Group, and an App Group
  needs a team ([ADR 0003](./adr/0003-host-app-widget-and-app-group.md)). A free Personal Team
  was enough on the machine this was built on.
- Claude Code and/or the Codex CLI, since both providers are read from what those tools leave on
  disk ([Data sources](./data-sources.md)).

## 1. Build and run the app

```sh
cp Local.xcconfig.example Local.xcconfig     # then set DEVELOPMENT_TEAM in it
xcodegen generate
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Debug \
  -derivedDataPath .build/xcode -allowProvisioningUpdates build
open .build/xcode/Build/Products/Debug/TokenMeter.app
```

`Local.xcconfig` is git-ignored. Your team ID is in Xcode under Settings, Accounts, or in
`defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`.

The app has no Dock icon or window. It lives in the menu bar as a gauge icon; click it to open the
panel with the bars. Without a team the app still builds and runs, but the panel warns that the
widget cannot read the snapshot.

## 2. Turn on the Claude quota

Claude's quota comes from Claude Code's status line, which has to be switched on once. Add this to
`~/.claude/settings.json`, using the absolute path of your checkout:

```json
"statusLine": {
  "type": "command",
  "command": "/absolute/path/to/tokenmeter/scripts/claude-statusline.sh"
}
```

If you already have a `statusLine`, wrap it rather than replacing it: your command has to keep
printing its own text, and the script has to receive the same JSON on stdin.

Then send any message in a Claude Code session. The script writes
`~/.tokenmeter/claude-statusline.json`, and within a minute the Claude bars fill in. Without this
step Claude shows an empty grey bar and its token count only.

Codex needs no setup: its quota is read from the logs it already writes.

## 3. Add the widget to the desktop

Right-click the desktop, choose **Edit Widgets**, search for **AI quota**, and add the small or
medium size. The app must be running: it is the app, not the widget, that reads the logs and
publishes the snapshot.

:::caution Not verified
The widget is registered with macOS and the app writes the snapshot, but the widget on the
desktop has not been seen running end to end. If it says "Open tokenmeter once to publish usage",
see [Troubleshooting](./troubleshooting.md).
:::

## 4. Keep it running

The app does not start at login. Add it under **System Settings, General, Login Items**. To keep
it after you delete the build folder, copy `TokenMeter.app` to `/Applications` first; that path was
not tested here.

## Check it from the terminal

```sh
swift run tokenmeter-probe
```

Prints each provider's 5h and 7d window with its tokens and remaining quota. If this shows the
numbers you expect and the panel does not, the problem is in the app, not the data.
