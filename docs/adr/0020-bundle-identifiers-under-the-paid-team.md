# ADR 0020 — Bundle identifiers under the paid team

Status: accepted (2026-10-29)

## Context

The app was signed with a free Personal Team, whose profile lasts seven days ([ADR 0010](./0010-distribute-a-prebuilt-app.md)).
The Apple Developer Program (Individual) gives a year and is needed for Developer ID signing and
notarization. Xcode had already registered `com.fmmenchi.tokenmeter` and its widget under the
Personal Team, and Apple does not let a second team register the same identifier: the build fails
with "The app identifier ... cannot be registered to your development team because it is not available".

## Decision

New identifiers, chosen once and kept, because notarized builds and the App Group depend on them:

| Item      | Before                           | After                                |
| :-------- | :------------------------------- | :----------------------------------- |
| App       | `com.fmmenchi.tokenmeter`        | `com.fmmenchi.tokenmeter.app`        |
| Widget    | `com.fmmenchi.tokenmeter.widget` | `com.fmmenchi.tokenmeter.app.widget` |
| App Group | `group.com.fmmenchi.tokenmeter`  | `group.com.fmmenchi.tokenmeter.app`  |

The widget identifier keeps the app's as its prefix, which an embedded extension requires.

## Consequences

- The snapshot moves to `~/Library/Group Containers/group.com.fmmenchi.tokenmeter.app/`. The app
  rewrites it on the first refresh, so nothing is migrated; the old container is left behind.
- Settings kept in the old app's preferences (launch at login) start fresh: the new bundle id is a
  different app to macOS. The old `TokenMeter.app` registration must be removed from login items.
- Anyone building from source gets the new identifiers and a team of their own through `Local.xcconfig`.
