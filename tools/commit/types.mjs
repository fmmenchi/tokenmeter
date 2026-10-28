/**
 * THE commit-type vocabulary — single source of truth, consumed by every
 * enforcement point so they can never drift:
 *
 * - `commitlint.config.mjs` (the `type-enum` rule, commit-msg hook)
 * - `tools/commit/check-branch-name.mjs` (the pre-push branch-name gate)
 *
 * Deliberately the same list as shared-platform: one vocabulary across the
 * repositories means a branch or commit written in either reads correctly in
 * the other, and there is one habit to keep rather than two.
 */
export const COMMIT_TYPES = [
  'build',
  'chore',
  'ci',
  'docs',
  'feat',
  'fix',
  'perf',
  'refactor',
  'revert',
  'style',
  'test',
];
