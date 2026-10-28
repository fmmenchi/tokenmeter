/**
 * Branch-name gate: `main`, or `<type>/<description>` where `<type>` comes
 * from the SAME vocabulary commitlint enforces (`tools/commit/types.mjs`) —
 * one list, zero drift between the hooks.
 *
 * The description is words of lowercase letters and digits joined by single
 * `-`, `.` or `/` — so `feat/---` and `feat/-x` are out — and at least three
 * characters long, so `feat/a` is out too. It may end with the issue number.
 *
 * Invoked by `.husky/pre-push` with the name of each remote branch being
 * pushed; with no argument it checks the current branch, for use by hand.
 */
import { execSync } from 'node:child_process';

import { COMMIT_TYPES } from './types.mjs';

const branch =
  process.argv[2] ??
  execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf-8' }).trim();

const WORD = '[a-z0-9]+';
const pattern = new RegExp(
  `^(main|(${COMMIT_TYPES.join('|')})/${WORD}(?:[.\\-/]${WORD})*)$`,
);
const description = branch.replace(/^[^/]+\//, '');

const wellFormed = pattern.test(branch);
const longEnough = branch === 'main' || description.length >= 3;

if (!wellFormed || !longEnough) {
  console.error(`✖ Branch "${branch}" is not semantic.`);
  if (wellFormed && !longEnough) {
    console.error(
      '  The description is too short to say what the branch is for.',
    );
  }
  console.error(
    '  Use <type>/<short-description> (kebab-case), ending with the issue number when one exists,',
  );
  console.error('  e.g. feat/skill-authoring-12, fix/installer-opencode-path.');
  console.error(`  Allowed types: ${COMMIT_TYPES.join(' ')}`);
  process.exit(1);
}
