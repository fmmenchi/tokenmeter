# ADR 0014 — An account is a provider entry with a home: the tool's folder, which the app writes into the file, and whose cards the panel arranges

Status: accepted (2026-11-04, with the plan of the [accounts](../features/2026-11-03-accounts/index.md); Fabio said "vai")

## Context

Claude Code reads one configuration folder, `~/.claude` or the one in `CLAUDE_CONFIG_DIR`; the Codex CLI reads `~/.codex` or
`CODEX_HOME`. Each folder holds one login, its settings and its logs, so a person with a work and a personal account has two
folders. Today every provider entry reads from the person's home ([ADR 0003](./0003-providers-in-one-config-file.md)): a second
Claude entry with its own paths already gives a second card and a second history, but the status line is set up in `~/.claude`
only ([ADR 0004](./0004-the-claude-status-line.md)), `/usage` runs for the default folder only, the problems say "Claude"
([ADR 0005](./0005-problems.md)), and nothing tells the person that a second folder exists. The
[proposal](../features/2026-11-03-accounts/proposal.md) adds a tab that adds, edits and removes accounts, which writes a file
that ADR 0003 lets only the migrations write; it moves the order and the visibility of the cards from Settings to the panel,
which ADR 0006 keeps in the app's defaults; and it shows the email a folder is signed in with, which for Codex lives in a file of
credentials.

Five things are structural: what an account is in the file, who writes the file, how the tool's folder reaches the code that
sets up the status line, runs `/usage` and reports problems, how a folder nobody named is found, and where the email comes
from. The lock on the panel moves no boundary: the preferences stay where ADR 0006 put them, only the view that writes them
changes.

## Decision

- **An account is a provider entry, and the entry gains one optional field, `home`.** It is the folder the tool reads: the one
  `CLAUDE_CONFIG_DIR` or `CODEX_HOME` would name, with `~` the person's home as everywhere in the file. An entry without it
  reads the tool's default folder, so the file of today is read as it was. The other paths of the entry (`log.root`, the
  quota's files, the plan's, `existsIf`) stay explicit, and `~` keeps its meaning: `home` serves the integration, not the
  readers. The id of an entry names files on disk from now on, so it is `[A-Za-z0-9._-]`, checked where the file is decoded.
- **The app writes whole entries into `providers.json`, through one writer.** ADR 0003 let only the migrations write the
  file; this adds three operations, add, replace and remove an entry, done by `ProviderConfigFile` the way the migrations do:
  the file is read as JSON, changed, kept as `providers.json.tokenmeter.bak` and written back atomically, sorted keys, two
  spaces. A file that cannot be used is never written: Settings says why and offers nothing. An added entry is the tool's seed
  entry with its paths rewritten for the folder and the id (`<home>/projects`, `<home>/.claude.json`,
  `~/.tokenmeter/<id>-statusline.json`, `<home>/sessions`), so what is written is explicit and readable by hand, and the
  seed becomes a template of the tool. When Edit changes the folder, a path is rewritten only where it still equals what the
  template gave for the old folder; a path the person wrote by hand is left alone, and the `.bak` has the file as it was.
  Removing an entry removes nothing else: the preferences that name its id stay and do nothing (ADR 0006), the usage store
  keeps its history by id ([ADR 0010](./0010-the-usage-store.md)), the folder and its login are not touched. The file stays
  the person's: it is read again after every write and at every detection, and a change by hand wins.
- **An integration takes the entry, not the home.** `ProviderIntegration` receives the provider entry it is asked about, with
  its id and its folder (the default when `home` is absent): the Claude status line is set up in that folder's `settings.json`,
  its wrapper and its saved original are named by the entry's id, `/usage` runs with `CLAUDE_CONFIG_DIR` set to the folder, the
  project overrides are read from that folder's `projects/`, and a problem's topic is the entry's id, so its id and its banner
  name the account. The status line script takes the entry's id as its one argument and writes
  `~/.tokenmeter/<id>-statusline.json`; with no argument it writes `claude-statusline.json`, byte for byte as today, so a
  status line already set up keeps working. One switch, "Set up the Claude quota automatically", applies to every Claude entry.
- **A tool's integration knows its folders.** It says the tool's default folder, whether a folder is one of the tool's (Claude
  Code: `.claude.json` and `projects/`; the Codex CLI: `auth.json` and `config.toml`), and who is signed in there. The detector
  looks, with the other checks, at the hidden folders at the top of the person's home and at the default folder, and a folder
  of a tool that no entry's `home` names (an absent `home` naming the default) becomes a problem of the general topic, one per
  folder, with the folder as its detail id, no fix and the Use page as its guide. The app, not the detector, turns it into
  Add it: it opens the sheet filled in from the folder. The `chatgpt` entry gains `"integration": "codex"` by the additive
  migration that gave `claude` its own, so the Codex CLI has an integration of its own, with no fix.
- **The email is a fact read from the folder, never kept.** Claude Code's is `oauthAccount.emailAddress` in the folder's
  `.claude.json`; the Codex CLI's is the `email` claim of the identity token in the folder's `auth.json`, read by decoding the
  token's payload and nothing else: the tokens are not kept, not logged and not written anywhere. The email reaches Settings
  and the banner's detail, not the snapshot, so the widget never has it. A folder signed in with an API key has none, and the
  folder is shown instead.
- **The lock changes who writes the preferences, not where they live.** The order, the visibility of a card and of its windows
  stay in the app's defaults and are applied to the snapshot (ADR 0006); the unlocked panel calls what Settings called, and
  whether the panel is unlocked is state of the view, which the panel forgets when it closes. The Providers tab goes;
  Accounts takes its place.

What the tab, the sheets, the lock and the welcome page look like is the feature's, in its
[proposal](../features/2026-11-03-accounts/proposal.md), and changes without an ADR.

## Consequences

- A person who already has two folders and wrote two entries by hand gets the status line and `/usage` in both as soon as
  the entries carry a `home`; the recipe in the Use page says so. Entries without `home` behave as before.
- The file is rewritten by the app on Add, Edit and Remove: its layout changes once (sorted keys), as the migrations did, and
  the `.bak` of the last write is the only copy kept.
- The Codex CLI's `auth.json` is opened by the app, which it never did; only one claim is read, and a test says that the
  identity reader returns the email and holds nothing else. A reader that finds no token, or one it cannot decode, returns
  nothing.
- A folder is found only at the top of the home; one elsewhere is added with Choose…, or by hand.
- Not verified until it is built: `/usage` with `CLAUDE_CONFIG_DIR` from a process the app launches, the status line's
  argument reaching the script when written in `settings.json`, the drag of a card in the panel, and the wrapper when two
  accounts had their own status line.
