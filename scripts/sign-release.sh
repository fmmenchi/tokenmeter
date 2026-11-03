#!/bin/sh
# Archive the app, export it signed with Developer ID and zip it into dist/ (ADR 0008).
set -eu
cd "$(dirname "$0")/.."

team=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Local.xcconfig)
[ -n "$team" ] || { echo "Set DEVELOPMENT_TEAM in Local.xcconfig" >&2; exit 1; }

# ADR 0011: a release the app can update to needs the public half of the signing key and a tag that names the version.
field() { sed -n "s/^ *$1: *'\{0,1\}\([^']*\)'\{0,1\} *\$/\1/p" project.yml | head -1; }
[ -n "$(field SU_PUBLIC_ED_KEY)" ] || { echo "SU_PUBLIC_ED_KEY is empty in project.yml: make the signing key first (docs: package and distribute)" >&2; exit 1; }
[ "$(git describe --tags --exact-match 2>/dev/null)" = "v$(field MARKETING_VERSION)" ] || {
  echo "HEAD must be tagged v$(field MARKETING_VERSION), the MARKETING_VERSION in project.yml" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "The tree has changes the tag does not: commit or discard them, a release is the tagged commit" >&2; exit 1; }

work=.build/release-sign
rm -rf "$work"
mkdir -p "$work" dist

cat > "$work/export.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST

xcodegen generate -q
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Release \
  -archivePath "$work/TokenMeter.xcarchive" -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$work/TokenMeter.xcarchive" \
  -exportOptionsPlist "$work/export.plist" -exportPath "$work/export" -allowProvisioningUpdates

app="$work/export/TokenMeter.app"
# The tag is exact and the tree is clean (checked above), so the name of the zip is the tag.
version=v$(field MARKETING_VERSION)
zip="dist/TokenMeter-$version.zip"
rm -f dist/TokenMeter-*.zip
# --norsrc: no AppleDouble (._*) entries for extended attributes; an unarchiver that does not know them writes them as files
# inside the bundle and breaks the seal (ADR 0008).
ditto -c -k --keepParent --norsrc "$app" "$zip"

echo "$zip"
codesign -dv "$app" 2>&1 | grep -E 'Authority|TeamIdentifier|Runtime|Signature' || true
