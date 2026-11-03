# ADR 0015 — The menu-bar item is an AppKit `NSStatusItem` that hosts the same SwiftUI panel

Status: accepted (2026-11-03, Fabio approved it after the spike of step 2)

## Context

[ADR 0001](./0001-app-architecture.md) made the menu-bar item a SwiftUI `MenuBarExtra` in its window style, and
[ADR 0014](./0014-welcome-tour.md) assumed the app could still reach its status item and open its panel from code. The spike of step 2 of the
welcome tour tested that on macOS 27.2, with a debug build:

- The status item's button can be found (an `NSStatusBarButton` in an `NSStatusBarWindow`) and a view can be added to it.
- The panel **cannot be opened from code**: `performClick`, sending the button's action, a synthetic `NSEvent` click and a `CGEvent` click
  posted to the process each left the panel closed. The button `MenuBarExtra` builds has no action and no target (`action = nil`), so its
  click goes through a private path; calling `mouseDown` on it by hand blocks the main thread.
- Not tried: a real mouse click, which is not the question; the tour needs the app to open the panel itself.

The tour has to open the panel by itself and draw its stops in it, so the scene that owns the item has to give way. ADR 0014 said that a failed
spike revises it and names this alternative.

## Decision

- **The menu-bar item is an `NSStatusItem` owned by the app**, with the gauge icon (and its dot) as the button's image, and its click
  toggles the panel. The panel is the same `MenuContent` SwiftUI view in an `NSHostingController`, shown in an `NSPopover` with
  `.transient` behaviour, anchored to the button, 300 points wide as now. A popover is the system's own panel for a status item, so the
  arrow, the shadow and closing on a click outside are the system's, not drawn by us.
- **The app can open and close the panel**: the status item object has `button.performClick` with a target and an action of ours, which the
  spike showed is what `MenuBarExtra` lacks. The tour uses that, and the ring and the popover of its first stop are views added to the
  button, which the spike showed works.
- **`@main` stays a SwiftUI `App`** with the `Window` for Settings, so Settings, the updater and the rest of the scenes do not move. An app
  delegate adaptor creates the status item at launch and holds the `Meter` the scenes already share. Nothing else of the app changes.
- **The icon is drawn as now** (`MenuBarIcon`, a template image, the dot when something needs a look). The label's accessibility text moves to
  the button.
- **What `MenuBarExtra` gave for free and has to be built:** open on click and close on a click outside or on Escape; refresh on every
  open (the `onAppear` of `MenuContent` keeps working, the popover creates the view once, so the refresh moves to the popover's
  `popoverWillShow`); `openWindow` for Settings, which a hosted view loses, so the panel gets the action from the app delegate; the
  panel's height follows its content.
- **A spike comes first again, on a throwaway branch**: an `NSStatusItem` with the real `MenuContent` in an `NSPopover`, opened from code,
  looked at in the light and dark appearances, with a skin, on a small display, with the panel growing and shrinking (stats view,
  a problem banner). The result is written here before step 3.

## Consequences

- **ADR 0001's "a host app with a `MenuBarExtra`" is amended** by this ADR; the rest (menu-bar only, not sandboxed, snapshot, widget) stands.
- Several things change under the panel, and each is checked on a Mac, not by drawing offscreen: the solid colour of a skin over the real
  popover material, the easter egg corners, the height changes, focus and keyboard (the text field-less panel needs none), and the panel on
  several displays.
- The popover has a small arrow the `MenuBarExtra` window does not. The design's mockups show the window without it; it is the system's look
  for a status item, and the tour's captions inside the panel are not affected.
- `MenuBarExtra`'s own behaviour is lost where macOS changes it for the better (it follows each new macOS); the status item and popover are
  old, documented API.
- If the spike shows the popover cannot hold the panel as it is (the height, the solid skin colour, the corner pieces), this ADR is revised before
  the app changes, and the fall-back is the second option of the tour: the popover on the icon says "click the icon", and the person
  opens the panel.
- Not verified at the time of writing: all of the spike above.

## Alternatives considered

- **Keep `MenuBarExtra` and open the panel by another call** (a `Scene` trick, `isInserted`, accessibility actions): none is documented, and
  the four tries of the spike say the private path is closed; it would break with a macOS update.
- **A borderless `NSPanel` of our own under the icon** instead of an `NSPopover`: more control of the look (no arrow, the same window as
  today), and more to build and keep right (position on several displays, closing, spaces, full screen). Chosen only if the popover fails
  the spike.
- **No automatic opening** (the person clicks the icon): costs nothing and keeps `MenuBarExtra`, and the tour loses its first
  hand-over; it is the fall-back above.
