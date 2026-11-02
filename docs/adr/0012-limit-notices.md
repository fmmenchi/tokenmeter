# ADR 0012 — Limit notices: a pure rule in the core, a ledger so that each is told once, and the system's notifications

Status: accepted (2026-11-02, with the plan of the [notifications](../features/2026-11-02-notifications/plan.md); Fabio asked to carry the feature to the end)

## Context

The panel says how much is left and the pace mark says whether it will last, and both need the person to look. A notification says it
when it matters. The data is already there: each window has the share left, the moment it resets, when it was last reported, and a
pace ([ADR 0002](./0002-quota-model-and-data-sources.md), `RunOut.swift`). The app is a menu-bar app with no Dock icon, not
sandboxed, and does not use `UserNotifications` today. A notice that comes twice, or that comes from an old figure, is worse than none.

## Decision

- **Three kinds of notice, each its own switch in Settings, all off by default**: _almost out_ (under 10% left), _running low_
  (under 30% left) and _will run out_ (the pace says the quota does not last until the reset). The 10% and the 30% are a choice, not
  a measurement, and are constants of the code. They are the thresholds that were proposed; no one proposed others.
- **The rule is a pure function in the core** (`LimitNotices.evaluate(snapshot:enabled:ledger:now:)`), with no framework and no
  clock but the `now` it is given, so the tests can say what it does. It returns the notices that are due and the ledger to keep.
- **What counts.** The windows of the snapshot the app draws, that is the providers and windows the person chose to show
  ([ADR 0006](./0006-display-preferences.md)). Only a window with a **reported** figure that is **recent** (not older than
  `WindowUsage.staleAfter`, the same ten minutes after which the card marks it "~"), with a reset time still ahead. A figure that
  is inferred (a reset), has no quota, or is old never notifies: it may already have changed.
- **Told once.** A notice is identified by the provider, the window (its id, which carries a model's name for a model limit), the
  moment it resets and its kind. A **ledger** keeps the identifiers already told, each with its reset moment; an entry is dropped a day
  after its reset, so the ledger does not grow, and a window that resets has a new moment and so arms again.
- **One at a time for a window.** When several kinds are due for a window at once, only the most urgent is posted, in the order
  _almost out_, _will run out_, _running low_, and the others due at that moment are written in the ledger as told: a jump from 50%
  to 8% says "almost out" once and not three times. A kind that is switched off is never written: turning it on later tells
  whatever is still due.
- **The ledger is kept by the app** in the user defaults, as JSON, with the choice of switches. It is not in the store of
  [ADR 0010](./0010-the-usage-store.md): it is not a fact seen, and the widget does not read it.
- **The system draws the notification.** The app asks macOS for permission the first time a switch is turned on, not at launch.
  While the permission is denied nothing is posted and nothing is written in the ledger; Settings says so and has a button to
  open System Settings. The text is one line under a title: "Claude · Weekly", then "9% left · resets in 2d 6h".
- **Nothing leaves the Mac and nothing is asked of anyone**: no network, no credentials.

## Consequences

- A notice only comes while the app runs and has read the quota; the app refreshes every minute, and Claude's quota is read from
  Claude Code every 15 minutes, so a notice can be late by that much.
- Turning a switch on at 25% tells it at once, because it is true and still due.
- Not verified: what a click on a notification does (the panel is a window of a menu-bar item and may not open from a notification),
  how macOS's Focus modes treat it, the address that opens the notification settings, and the look on a real Mac.
- Not decided here: a sound, a button on the notification, and different thresholds for each provider.
