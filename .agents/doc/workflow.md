# Workflow — agent rules

- **ADR first** for any structural decision: `docs/adr/NNNN-title.md`, status line, context,
  decision, consequences. Write it before the code.
- **Features** follow one pattern: proposal, ADR, plan, then code. See `.agents/doc/features.md`.
- **Branches** are semantic (`feat/…`, `docs/…`), checked by the pre-push hook. Never `main`.
- **Commits** are conventional, one concern each; the `commit-msg` hook runs commitlint.
  Types: `tools/commit/types.mjs`.
- **Hooks** are never bypassed. A failing gate gets fixed.
- **Never push.** Fabio pushes. **Merge** a finished branch into `main` with a merge commit: `git checkout main`, then
  `git merge --no-ff <branch>`. Never fast-forward, never rebase onto `main`. A branch holds one feature or one fix, and
  the merge is the last step of its plan.
- **Gate:** `pnpm run check` (prettier, `swift test`, docs build). CI mirrors it
  (`.github/workflows/ci.yml`: Swift on macOS, web on Ubuntu, commitlint on PRs).
- **Docs** deploy to GitHub Pages from `main` (`docs.yml`).
