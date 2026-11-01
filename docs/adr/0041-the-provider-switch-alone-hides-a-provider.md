# ADR 0041 — The provider's switch alone hides a provider

Status: proposed (2026-11-01); replaces the lines of [ADR 0037](./0037-a-window-exists-only-if-the-data-lists-it.md) that say
choosing no window hides the provider and that showing it with the eye selects every window, and changes the eye of
[ADR 0036](./0036-a-provider-can-be-hidden.md) into a switch

## Context

A provider can be hidden in two ways: with the eye of [ADR 0036](./0036-a-provider-can-be-hidden.md), or by turning off its
last window, which [ADR 0037](./0037-a-window-exists-only-if-the-data-lists-it.md) makes the same preference. A hidden provider shows
every window off, so the choice it had is not visible, and showing it with the eye selects every window, so the choice is
lost. Two controls for one state is what made it unclear what a click on a window does (`DisplayPreferences.select`,
`DisplayPreferences.setShown`, `SettingsView.swift`).

## Decision

**The provider has one switch, and it is the only thing that hides it. Each window has a switch of its own**
([the proposal](../features/2026-11-01-settings-switches/proposal.md)). It is the pattern of a master switch with options
under it, as macOS Settings does it.

- **The provider's switch** replaces the eye, beside the name. Off is the same preference as hidden (`hidden` in the
  defaults): no card in the panel or the widget, not in the menu-bar percentage. Nothing else in the reading changes.
- **Under the provider a vertical list**, one row per window with a switch, and a model's limit indented under its window,
  with a smaller switch. This replaces the segments of `WindowSelector` of ADR 0037.
- **Turning a window off never hides the provider.** The last window that is on cannot be turned off:
  `DisplayPreferences.select` refuses an empty choice, and its switch does not turn off, with a tooltip that says to turn
  the provider off.
- **A provider that is off keeps its list**, dimmed and not touchable, with the choice it had, windows and models. Turning it
  on gives it back as it was: `setShown` no longer selects every window, and hiding no longer clears the windows or the models.
- **A model's limit is a child of its window**: dimmed and not touchable while the window is off, and on with it by default,
  as in ADR 0037 (selecting a window turns its models on).
- **At least one provider stays on**, as in ADR 0036: the switch of the last one that is on is disabled.
- **Saved preferences are read as they are.** A provider hidden before has no windows saved, so it comes back with every
  window; one with a choice saved keeps it. No key of the defaults changes.
- **The switch is the system `Toggle`** that Settings uses for "Launch at login".

## Consequences

- Settings has one kind of control. The row of a provider with two windows is taller: three rows where it had two.
- The choice of windows can be changed only while the provider is on. Changing it while it is off was drawn and dropped:
  a control that turns another on is the ambiguity this removes.
- `VisibilityButton` and `WindowSelector` go, and the Design System loses their cards and gains two: the provider's
  switch and the window row.
- A person who had hidden a provider by turning off its last window sees it hidden as before; nothing is migrated.
- Not verified: how the system switch looks at the small size in a grouped form, and how the indented model row lines up
  with the window's label, since both were drawn in HTML and not in SwiftUI.
