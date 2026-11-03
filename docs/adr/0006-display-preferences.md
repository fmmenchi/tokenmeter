# ADR 0006 — Display preferences: order, windows and visibility are the app's, not the file's

Status: accepted (2026-10-30, consolidated 2026-11-02 from the ADRs on provider cards, hiding a provider, which windows exist and the provider's switch)

## Context

The order of providers decides what the medium widget shows, and nobody could hide a provider or a window they do not watch.
`providers.json` is the user's file and the app does not rewrite what the person wrote: the only changes are the additions of the migrations, once each and with a `.tokenmeter.bak` ([ADR 0003](./0003-providers-in-one-config-file.md)).

## Decision

- **The order, the visible windows and the hidden providers are preferences of the app**, kept in its defaults by provider id
  (`DisplayPreferences`). The file's order is the default, and a provider with no preference is last. A preference for a provider
  that leaves the file stays and does nothing.
- **What is read does not change.** Collection, the snapshot's windows and the problems follow the file; only what is shown follows
  the preferences. **The app applies them when it writes the snapshot** (`Snapshot.applying`), so the widget draws what it is
  given. Settings reads the unfiltered list from the app.
- **The choice of windows is a set by name**, one by one, taken from the windows the data lists ([ADR 0002](./0002-quota-model-and-data-sources.md)),
  never from a fixed list. A model's limit is under its window, on unless the person turned it off (`hiddenModels`), and turning its
  window on turns it on. At least one window always stays on. A hidden window is out of every figure shown, and it raises no problem. (Until v0.3.0 the menu bar showed the lowest percentage of the visible windows; it is the icon alone now.) A preference naming windows that are gone does no harm:
  if nothing it names is left, every window shows.
- **Only one preference hides a provider: `hidden`.** A window never does. `DisplayPreferences.select` refuses an empty choice and
  never touches `hidden`, and hiding and showing keep the windows and the models, so a provider shown again comes back as it
  was. A hidden provider has no card in the panel or the widget, but keeps its place; its
  problems still show in the panel. Saved preferences are read as they are: a provider hidden before has no windows saved and comes
  back with every window.
- **One provider always stays shown**: the last one cannot be hidden, and if every provider were hidden the first in order is shown.
  A provider added later is shown.

## Consequences

- The widget's order follows the person, which is the practical reason to reorder.
- The windows of a provider that is off can be read, and are changed only while it is on.
- How Settings looks is in the proposals of the features ([Features](../features/index.md)), not here.
