# ADR 0011 — Updates: Sparkle, a feed attached to each release, and a build number that goes up

Status: accepted (2026-11-02, with the plan of the [updates](../features/2026-11-02-updater/plan.md))

## Context

Whoever installed v0.1.0 has no way to learn that v0.2.0 exists: the app does not look. The widget is an extension inside
`TokenMeter.app/Contents/PlugIns`, so it has no update path of its own and changes when the app is replaced. An updater has to
replace the whole app, quit and open it again, and leave what the app keeps alone ([ADR 0010](./0010-the-usage-store.md)).

Today the project has no dependency outside Apple's and makes no network request of its own: the README, the use pages and
`data-sources.md` say so. An updater changes both.

A trial, on 2026-11-02, with Sparkle 2.10.1 in the app target and made-up versions in a temporary folder (nothing of the
author's data touched), showed:

- It builds in Swift 6. The export of the project's signing flow ([ADR 0008](./0008-signing-and-distribution.md)) signs Sparkle's
  helper programs with the Hardened Runtime and a timestamp, and `codesign --verify --deep --strict` passes, so
  `scripts/sign-release.sh` needs no change. Notarization was not tried.
- An update from a local feed worked end to end: the app was offered it, quit, was replaced and opened as the new version; the
  widget inside it read the new version on disk and in the system's list. **The widget on the desktop was not seen refreshing.**
- An update must carry an EdDSA signature. The signature of the same Apple team, with no key, did not work: Sparkle stopped at
  start ("updates need to be signed with an EdDSA key").
- A scheduled check showed the system window above other windows but did not give the app the focus. A check started from
  the menu with a real click was not tried.
- Sparkle compares `CFBundleVersion`, and both Info.plist files wrote 1.0 and build 1 by hand. v0.2.0 reports 1.0 (1) and
  **does not contain Sparkle**, so it will never look for an update.

## Decision

- **Sparkle 2, pinned to an exact version (2.10.1), in the app target only.** `TokenMeterCore` and the widget stay free of
  dependencies. It is the project's first dependency outside Apple's, chosen because replacing a running app, relaunching it
  and verifying the download is the part that is easy to get wrong.
- **The app makes one network request of its own: the list of versions.** When "Update automatically" is on, which it is by
  default, it asks once a day for `https://github.com/fmmenchi/tokenmeter/releases/latest/download/appcast.xml`, and also when
  the user presses **Check now**. The zip is downloaded only after the user says yes. No system profile is sent
  (`SUEnableSystemProfiling` is false). The sentences "no network request of its own" in the README and the pages are rewritten to
  say it. The reading of the logs and the quota stay as they are: no credentials, and Claude's quota still comes from Claude
  Code running its own `/usage`.
- **It tells, and the user installs** (`SUAutomaticallyUpdate` false): the system's update window asks, and nothing is
  installed without a yes, unless the person themselves turns on the automatic install that Sparkle's window offers
  (`SUAllowsAutomaticUpdates` is true). For whoever misses the window, the panel shows a notice at its top and the menu-bar icon shows the
  dot of the [icon-only menu bar](../features/2026-11-02-menu-bar-icon-only/index.md), the same dot as a problem.
- **The feed is a file attached to each GitHub release**, at the address of the latest release, so a release and its feed cannot
  fall out of step. **To be checked:** that Sparkle follows that redirect.
- **The signing key** is made once on the author's Mac with Sparkle's `generate_keys`, which keeps it in the login Keychain; a
  copy is kept in a password manager. Its public half is in `project.yml` (`SU_PUBLIC_ED_KEY`); the private half is never in the
  repository, in a script or in a chat. Every release zip is signed with it.
- **The version is read from `project.yml`.** `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` feed both Info.plist files. The
  build number is an integer that **goes up by one in every release**; v0.2.0 reported 1, so the first version with an updater
  is build 2. The release script refuses a build number that is not greater than the last one in the feed.
- **What changed is one click away.** Each item of the feed points to a clean page of the docs site with the notes of that version
  (`/release-notes/v<version>.html`, made from the changelog by `scripts/release-notes.sh`), which the update window shows and
  **What's new** opens; that page links to the whole changelog.
- **An update starts the app again, and the app migrates and does not start again from nothing.** The schema of the store and the
  fields of `providers.json` are migrated at launch, as they already are, and the ingestor reads only what changed since the last
  pass that finished ([ADR 0010](./0010-the-usage-store.md), commit `0ed6380`).
- **Notarization is still a step apart** ([ADR 0008](./0008-signing-and-distribution.md)), asked every time.

## Consequences

- **The first version with the updater is installed by hand**, by dragging it into Applications. From then on the app updates itself.
- **The author keeps a key.** If it is lost, no installed copy can update itself: the people who installed it download the app
  again. That is why a copy is kept outside the Keychain.
- **Every release has three more steps**: raise the build number, sign the zip with the key, publish `appcast.xml` beside the zip.
  They are in a script and the release is still published only on the author's word.
- The project depends on Sparkle's releases and on GitHub for the feed. A different host for the feed is a change of one URL.
- **Not verified**: the widget refreshing on the desktop after an update, the check started from the menu with a click, an update
  downloaded from the web with Gatekeeper's quarantine, a migration run by a real update, and the redirect of the feed address.
  The plan has a step for each.
- Not decided here: installing without asking (it is off) and the wording of Sparkle's own window.
