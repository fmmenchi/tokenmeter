---
title: Add the Widget
sidebar_label: Add the Widget
sidebar_position: 4
---

# Add the Widget

Put an account's quota on the desktop or in Notification Center: one widget for each account.

## Intent

The menu-bar panel needs a click. A widget shows how much is left of one account's plan where you can see it all the time. With
two accounts, add two widgets.

## Step 1: Make sure the app is running

The widget is sandboxed and cannot read your logs. The app reads them and writes a snapshot into
the App Group container `<TeamID>.tokenmeter`; the widget only draws it. If the app is
not running the widget keeps showing the last snapshot.

## Step 2: Add it

Right-click the desktop, choose **Edit Widgets**, search for **AI quota** and add the small or the
medium size.

## Step 3: Choose the account

Right-click the widget and choose **Edit**: pick the account it shows among the cards of the panel. A widget that has none chosen
shows the first card. If you hide or remove its account, the widget says so; choose another one the same way.

## What it shows

- **The card's title**, and in the medium size its plan.
- **A gauge for each window, two at most**: its name above, the figure inside the ring, the reset under it. The ring fills as the
  bar would, green with plenty left, orange under 40%, red under 15%, and reads left or used as you chose in Settings.
- **A model's own limit stays inside its window**: a thin inner ring in that window's gauge is the lowest of them. The small widget
  writes it under the reset ("Fable 6%"); the medium one lists them all beside the gauges.
- **An old reading** has "~" before its figure and its ring at half strength, and the widget says its age at the top right.
- **Your skin**: its colours and its typeface. The shape of its bars does not apply to a ring.

Only the quota and the reset: tokens, the moment a window runs out and the stats are in the panel.

## What it refreshes on

The app writes a new snapshot every 60 seconds and asks WidgetKit to reload. The widget also
schedules itself every 15 minutes, and at each upcoming reset time, so a gauge flips to its reset
state on time instead of at the next refresh.

:::caution[Not seen on a Mac yet]
The widget for each account is built and its view was drawn with sample data, but it has not been seen on a desktop yet: the
account picker in Edit, a widget already placed before the update, and the desktop's muted rendering, which takes the colour out of
the gauges (the figure stays written), are still to be checked. If it says "Open tokenmeter once to publish usage", see
[Troubleshooting](./troubleshooting.md).
:::

## Related

- [Accounts](./accounts.md)
- [Install and Run](../develop/build-and-run.md)
- [Architecture](../develop/concepts.md)
