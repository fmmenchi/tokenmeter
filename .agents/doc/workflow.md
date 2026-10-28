# Workflow — agent rules

- **ADR first** for any structural decision: `docs/adr/NNNN-title.md`, status line, context,
  decision, consequences. Write it before the code.
- **Branches** are semantic (`feat/…`, `docs/…`), checked by the pre-push hook. Never `main`.
- **Commits** are conventional, one concern each; the `commit-msg` hook runs commitlint.
  Types: `tools/commit/types.mjs`.
- **Hooks** are never bypassed. A failing gate gets fixed.
- **Never push, never merge.** Fabio does both.
- **Gate:** `pnpm run check` (prettier, `swift test`, docs build). CI mirrors it
  (`.github/workflows/ci.yml`: Swift on macOS, web on Ubuntu, commitlint on PRs).
- **Docs** deploy to GitHub Pages from `main` (`docs.yml`).
