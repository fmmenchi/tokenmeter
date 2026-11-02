# ADR 0012 — Limit notices: the rule is a pure function of the core, what was told is kept by the app, and the system shows the notification

Status: accepted (2026-11-02, with the plan of the [notifications](../features/2026-11-02-notifications/plan.md); Fabio asked to carry the feature to the end)

## Context

The app has the data for a notice, the share left of each window, its reset, when it was reported and a pace
([ADR 0002](./0002-quota-model-and-data-sources.md)), and no way to speak without being looked at. It is a menu-bar app with no
Dock icon, not sandboxed, and it does not use `UserNotifications` today. Where the rule lives, where what was already told is kept
and who shows the notification are structural: they decide what can be tested and what the widget can see.

## Decision

- **The rule is a pure function in `TokenMeterCore`**: the snapshot, the kinds that are on, what was told and `now` go in, the
  notices that are due and what is now told come out. It uses no framework and no clock of its own, so the tests can say what it does.
- **What was told is kept by the app, in the user defaults**, as JSON. It is not a fact seen, so it is not in the store of
  [ADR 0010](./0010-the-usage-store.md), and the widget does not read it.
- **The system shows the notification**, through `UserNotifications`, from a small object of the app target that asks for permission
  and posts. The core never imports it. The permission is asked when first needed, not at launch.
- **Nothing leaves the Mac**: no network and no credentials.

What a notice says, when it comes, how many kinds there are and their thresholds are the feature's, in its
[proposal](../features/2026-11-02-notifications/proposal.md), and change without an ADR.

## Consequences

- A notice only comes while the app runs and has read the quota; the app refreshes every minute and Claude's quota is read every
  15 minutes, so a notice can be that late.
- The rule is tested in the core, which the gate builds; the notifier is in the app target, which only `xcodebuild` builds.
- Not verified: how macOS treats the notification (permission, Focus modes, a click on it) and the address of its settings.
