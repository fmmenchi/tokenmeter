#!/bin/sh
# Runs release-notes.sh on a made-up changelog in a throwaway folder, never the real changelog or the real static folder.
set -u
here=$(cd "$(dirname "$0")" && pwd)
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; fail=1; fi; }

work=$(mktemp -d)
cat > "$work/changelog.md" <<'MD'
# Changelog

Intro that is not a version.

## 0.2.0 {#v0-2-0}

Released on 2026-01-02.

- **Bold** and `code` and _it_ with [a page](./stats.md) and [outside](https://example.com/z), and a line that
  goes on in the next one.
- A <script>tag</script> is text, not markup.
- A [quote](https://x.example/" onclick="alert(1)) and a [script](javascript:alert(1)) are not links.

## 0.1.0 {#v0-1-0}

- The older one.
MD
run() { (cd "$here/.." && CHANGELOG="$work/changelog.md" OUT_DIR="$work/out" sh scripts/release-notes.sh "$1" >"$work/out.txt" 2>&1; echo $?); }
page="$work/out/v0.2.0.html"

check "a version in the changelog: exit 0" "$(run 0.2.0)" 0
check "the title names the version" "$(grep -c '<title>tokenmeter 0.2.0</title>' "$page")" 1
check "bold" "$(grep -c '<strong>Bold</strong>' "$page")" 1
check "code" "$(grep -c '<code>code</code>' "$page")" 1
check "italic" "$(grep -c '<em>it</em>' "$page")" 1
check "a link to a page of the docs becomes an address of the site" "$(grep -c 'href="https://fmmenchi.github.io/tokenmeter/use/stats"' "$page")" 1
check "an outside link stays" "$(grep -c 'href="https://example.com/z"' "$page")" 1
check "a line that goes on joins its item" "$(grep -c 'and a line that goes on in the next one' "$page")" 1
check "markup in the notes is text" "$(grep -c '&lt;script&gt;' "$page")" 1
check "an address that closes the attribute is not a link" "$(grep -c 'onclick=' "$page")" 0
check "a javascript address is not a link" "$(grep -c 'href="javascript' "$page")" 0
check "no real script in the page" "$(grep -c '<script>' "$page")" 0
check "the text of the date is there" "$(grep -c 'Released on 2026-01-02' "$page")" 1
check "another version is not in it" "$(grep -c 'The older one' "$page")" 0
check "a link to the whole changelog" "$(grep -c 'use/changelog"' "$page")" 1
check "colours for both appearances" "$(grep -c 'prefers-color-scheme: dark' "$page")" 1
check "a version that is not in the changelog: refused" "$(run 9.9.9)" 1
check "and no page is written for it" "$([ -f "$work/out/v9.9.9.html" ] && echo yes || echo no)" no

rm -rf "$work"
exit $fail
