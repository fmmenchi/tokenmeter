---
title: Add the Widget
sidebar_label: Add the Widget
sidebar_position: 4
---

# Add the Widget

Put the bars on the desktop or in Notification Center.

## Intent

The menu-bar panel needs a click. The WidgetKit widget shows the same bars where you can see them
all the time.

## Step 1: Make sure the app is running

The widget is sandboxed and cannot read your logs. The app reads them and writes a snapshot into
the App Group container `<TeamID>.tokenmeter`; the widget only draws it. If the app is
not running the widget keeps showing the last snapshot.

## Step 2: Add it

Right-click the desktop, choose **Edit Widgets**, search for **AI quota** and add the small or the
medium size.

## Step 3: What it refreshes on

The app writes a new snapshot every 60 seconds and asks WidgetKit to reload. The widget also
schedules itself every 15 minutes, and at each upcoming reset time, so a bar flips to its reset
state on time instead of at the next refresh.

:::caution[Not verified]
The widget is registered with macOS and the app writes the snapshot, but the widget on the desktop
has not been seen running end to end. If it says "Open tokenmeter once to publish usage", see
[Troubleshooting](./troubleshooting.md).
:::

## Related

- [Install and Run](../develop/build-and-run.md)
- [Architecture](../develop/concepts.md)
