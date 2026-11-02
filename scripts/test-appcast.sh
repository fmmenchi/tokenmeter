#!/bin/sh
# Runs appcast.sh on a made-up zip and a made-up signer, in a throwaway folder, never the real dist/ or the real key.
# What it checks is the feed's content and the refusals; the signature itself is checked by hand, with the real key.
set -u
here=$(cd "$(dirname "$0")" && pwd)
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; fail=1; fi; }

work=$(mktemp -d)
mkdir -p "$work/dist"
printf 'zip' > "$work/dist/TokenMeter-v0.3.0.zip"
cat > "$work/sign" <<'SH'
#!/bin/sh
echo 'sparkle:edSignature="TESTSIGNATURE" length="3"'
SH
chmod +x "$work/sign"
project() { printf "settings:\n  base:\n    MARKETING_VERSION: '0.3.0'\n    CURRENT_PROJECT_VERSION: '%s'\n        SU_PUBLIC_ED_KEY: '%s'\n" "$1" "$2" > "$work/project.yml"; }
feed() { printf '<item><sparkle:version>%s</sparkle:version></item>' "$1" > "$work/previous.xml"; }
run() { (cd "$here/.." && OUT_DIR="$work/out" PROJECT_YML="$work/project.yml" SIGN_UPDATE="$work/sign" PREVIOUS_APPCAST="$work/previous.xml" \
  sh scripts/appcast.sh "$work/dist/TokenMeter-v0.3.0.zip" >"$work/out.txt" 2>&1; echo $?); }

project 2 ""; feed 1
check "no signing key: refused" "$(run)" 1
check "no signing key: no feed written" "$([ -f "$work/out/appcast.xml" ] && echo yes || echo no)" no

project 2 "PUBLICKEY"; : > "$work/previous.xml"
check "first feed: exit 0" "$(run)" 0
feedfile="$work/out/appcast.xml"
check "the version" "$(sed -n 's/.*<sparkle:shortVersionString>\(.*\)<\/sparkle:shortVersionString>.*/\1/p' "$feedfile")" 0.3.0
check "the build" "$(sed -n 's/.*<sparkle:version>\(.*\)<\/sparkle:version>.*/\1/p' "$feedfile")" 2
check "the notes link is the clean page of the version" "$(sed -n 's/.*<sparkle:releaseNotesLink>\(.*\)<\/sparkle:releaseNotesLink>.*/\1/p' "$feedfile")" "https://fmmenchi.github.io/tokenmeter/release-notes/v0.3.0.html"
check "the download is the release's asset" "$(grep -c 'url="https://github.com/fmmenchi/tokenmeter/releases/download/v0.3.0/TokenMeter-v0.3.0.zip"' "$feedfile")" 1
check "the signature and the length are the signer's" "$(grep -c 'sparkle:edSignature="TESTSIGNATURE" length="3"' "$feedfile")" 1

feed 2
check "a build that does not go up: refused" "$(run)" 1
feed 5
check "a build lower than the published one: refused" "$(run)" 1
feed 1
check "a build that goes up: exit 0" "$(run)" 0

rm -rf "$work"
exit $fail
