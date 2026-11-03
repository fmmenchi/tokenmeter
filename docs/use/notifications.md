---
title: Notifications
sidebar_label: Notifications
sidebar_position: 8.5
---

# Notifications

tokenmeter can tell you with a notification when a window is running out, so you do not have to open the panel to find out. They
are **off** until you turn them on.

## The three notices

Turn each on by itself, in the tab **Notifications** of Settings:

| Notice                            | It comes when                                                                  |
| :-------------------------------- | :----------------------------------------------------------------------------- |
| **Almost out**                    | Under 10% of a window is left.                                                 |
| **Running low**                   | Under 30% of a window is left.                                                 |
| **Will run out before the reset** | At the pace you have used it, the quota will not last until the window resets. |

A notification has the provider and the window as its title and one line under it: `Claude · Weekly`, then
`9% left · resets in 2d 6h`. For a model's limit the title ends with the model: `Claude · Weekly · Fable`.

## What it does and does not do

- **Once for each window and each reset.** A window that was told is not told again until it resets and a new one begins.
- **One at a time for a window.** If several are due at once, you get the most urgent: from 50% to 8% it says "almost out" once, not
  three times.
- **Only the windows you show.** A provider or a window you turned off in [Settings](./configure-providers.md) does not notify.
- **Only a recent reading.** A figure the panel marks with `~` because it is old does not notify: it may already have changed.
- **Turning one on at 25% tells it at once**, because it is true and still due.
- It needs the app to be running, and it is as late as the quota is: the app looks every minute and reads Claude's quota every 15
  minutes ([Reading the bars](./bars.md)).
- Nothing leaves your Mac for this, and nothing is asked of anyone.

## Permission

The first time you turn a notice on, macOS asks whether tokenmeter may send notifications. If you said no, or turned them off later
in System Settings, Settings says so and has a button **Open System Settings**; the switches are dimmed until you allow them.

## Not tried yet

How a click on the notification behaves, how Focus modes treat it, and the exact page that the button opens in System Settings are
not verified.

## Related

- [Reading the bars](./bars.md)
- [Settings: choose the providers and windows](./configure-providers.md)
- [Changelog](./changelog.md)
