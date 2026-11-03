#!/bin/sh
# Write dist/appcast.xml for the notarized zip in dist/ (ADR 0011): the file the app asks for once a day, attached to the release.
# Run it after notarize.sh: the signature is of the final zip, and stapling changes the zip.
#   scripts/appcast.sh [zip]      (OUT_DIR changes where the feed is written, dist by default)
# The version and the build number are read from project.yml, so the app and the feed cannot disagree. The build number must be
# greater than the one in the feed that is published now (PREVIOUS_APPCAST: a file; by default the feed of the latest release).
# A feed that cannot be fetched stops the script: only a 404, no release with a feed yet, counts as a first feed. The zip must be
# the one of this version, TokenMeter-v<version>.zip, so a build made by hand in between is never signed as the release.
# The signature is made by Sparkle's sign_update with the key in the login Keychain; the private key is never read here.
set -eu
cd "$(dirname "$0")/.."

project=${PROJECT_YML:-project.yml}
site=https://fmmenchi.github.io/tokenmeter
repo=https://github.com/fmmenchi/tokenmeter

field() { sed -n "s/^ *$1: *'\{0,1\}\([^']*\)'\{0,1\} *\$/\1/p" "$project" | head -1; }
version=$(field MARKETING_VERSION)
build=$(field CURRENT_PROJECT_VERSION)
key=$(field SU_PUBLIC_ED_KEY)
[ -n "$version" ] && [ -n "$build" ] || { echo "project.yml has no MARKETING_VERSION or CURRENT_PROJECT_VERSION" >&2; exit 1; }
[ -n "$key" ] || { echo "SU_PUBLIC_ED_KEY is empty in project.yml: make the signing key first (docs: package and distribute)" >&2; exit 1; }

zip=${1:-$(ls dist/TokenMeter-*.zip 2>/dev/null | head -1)}
[ -f "$zip" ] || { echo "No zip to sign: run sign-release.sh and notarize.sh first" >&2; exit 1; }
[ "$(basename "$zip")" = "TokenMeter-v$version.zip" ] || {
  echo "The zip is $(basename "$zip"), not TokenMeter-v$version.zip: it is not the build of this version" >&2; exit 1; }

previous=${PREVIOUS_APPCAST:-}
if [ -z "$previous" ]; then
  previous=$(mktemp)
  code=$(curl -sL -o "$previous" -w '%{http_code}' "$repo/releases/latest/download/appcast.xml" 2>/dev/null) || code=unreachable
  case "$code" in
    200) ;;
    404) : > "$previous" ;;   # no release with a feed yet: this is the first
    *) echo "The published feed could not be fetched ($code), so its build number is unknown: try again, or give PREVIOUS_APPCAST" >&2
       exit 1 ;;
  esac
fi
last=$(sed -n 's/.*<sparkle:version>\([0-9][0-9]*\)<\/sparkle:version>.*/\1/p' "$previous" | sort -n | tail -1)
if [ -n "$last" ] && [ "$build" -le "$last" ]; then
  echo "Build $build is not greater than $last, the one in the published feed: raise CURRENT_PROJECT_VERSION in project.yml" >&2
  exit 1
fi

sign=${SIGN_UPDATE:-$(ls .build/xcode/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update 2>/dev/null | head -1)}
[ -x "$sign" ] || { echo "Sparkle's sign_update was not found: build the app once with xcodebuild" >&2; exit 1; }
signature=$("$sign" "$zip")   # sparkle:edSignature="..." length="..."

date=$(LC_ALL=C date -u +"%a, %d %b %Y %H:%M:%S +0000")
out=${OUT_DIR:-dist}/appcast.xml
mkdir -p "$(dirname "$out")"
cat > "$out" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>tokenmeter</title>
    <item>
      <title>Version $version</title>
      <pubDate>$date</pubDate>
      <sparkle:version>$build</sparkle:version>
      <sparkle:shortVersionString>$version</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$site/release-notes/v$version.html</sparkle:releaseNotesLink>
      <enclosure url="$repo/releases/download/v$version/$(basename "$zip")" type="application/octet-stream" $signature/>
    </item>
  </channel>
</rss>
XML
echo "$out (version $version, build $build)"
