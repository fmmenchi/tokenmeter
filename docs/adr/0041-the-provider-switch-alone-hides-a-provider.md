# ADR 0041 — Only the provider's own preference hides it

Status: accepted (2026-11-01); replaces the lines of [ADR 0037](./0037-a-window-exists-only-if-the-data-lists-it.md) that say
choosing no window hides the provider and that showing it selects every window, and the way [ADR 0036](./0036-a-provider-can-be-hidden.md)
hides one

## Context

A provider could be hidden in two ways: with its own preference ([ADR 0036](./0036-a-provider-can-be-hidden.md)) or by
choosing no window ([ADR 0037](./0037-a-window-exists-only-if-the-data-lists-it.md)). Two paths to one state made what a
change of windows does depend on the other, and showing a provider selected every window, so a choice was lost.

## Decision

**One preference hides a provider, and the windows never do** ([the proposal](../features/2026-11-01-settings-switches/proposal.md)).

- `DisplayPreferences.hidden` is the only thing that hides a provider.
- `DisplayPreferences.select` refuses an empty choice and never touches `hidden`: the last window that is on stays on.
- Hiding and showing a provider keep its windows and its models, so a provider shown again comes back as it was
  (`setShown` no longer selects every window).
- At least one provider stays shown, as in ADR 0036.
- Saved preferences are read as they are: a provider hidden before has no windows saved and comes back with every window.
  No key of the defaults changes.

## Consequences

- The windows of a provider that is off can be kept and read, and are changed only while it is on.
- `VisibilityButton` and `WindowSelector` are gone; the Settings views are in the feature's proposal.
