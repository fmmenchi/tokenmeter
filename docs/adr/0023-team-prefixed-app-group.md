# ADR 0023 — A team-prefixed App Group

Status: accepted (2026-10-29)

## Context

With the paid team ([ADR 0020](./0020-bundle-identifiers-under-the-paid-team.md)) the app was signed with
`group.com.fmmenchi.tokenmeter.app`, and the snapshot for the widget was never written. The write had
been hidden by `try?`; once logged, it said "You don't have permission to save the file snapshot.json".
Cause, checked on the built app: none of the provisioning profiles (development app, widget, and the
Developer ID export) carries `com.apple.security.application-groups`. The group was signed into the
app but never enabled on the App ID in the developer account, so macOS denies the container. Changing
the name made no difference (`.shared` failed the same way), so it is not the `.app` suffix.

## Decision

Use an App Group that macOS allows without registering it: **`<TeamID>.tokenmeter`**.

- `project.yml` writes the entitlement as `$(TeamIdentifierPrefix)tokenmeter`, and the same value into
  each target's Info.plist as `AppGroupIdentifier`.
- `SnapshotStore.appGroup` reads that key from `Bundle.main`. It is `nil` where there is none (the
  probe, the tests), so those never touch a container.
- `Meter` logs a failed write (`os.Logger`, subsystem `com.fmmenchi.tokenmeter.app`) and reloads the
  widget only after a successful one. A swallowed error is what hid this.

Registering `group.…` in the developer account was the alternative. It needs a manual step per team
and per fork, and was not needed.

## Consequences

- The container is `~/Library/Group Containers/<TeamID>.tokenmeter/`. Whoever builds with their own
  `DEVELOPMENT_TEAM` gets their own, with no portal step.
- The earlier `group.com.fmmenchi.tokenmeter*` folders are left behind and unused.
- Verified: the app writes `snapshot.json` there. **Not verified**: that the sandboxed widget reads it
  on the desktop; that needs the widget added.
- The earlier notarized build had the old entitlement, so it is superseded and is notarized again.
