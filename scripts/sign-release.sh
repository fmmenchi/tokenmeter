#!/bin/sh
# Archive the app, export it signed with Developer ID and zip it into dist/ (ADR 0021).
set -eu
cd "$(dirname "$0")/.."

team=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' Local.xcconfig)
[ -n "$team" ] || { echo "Set DEVELOPMENT_TEAM in Local.xcconfig" >&2; exit 1; }

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
version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)
zip="dist/TokenMeter-$version.zip"
rm -f dist/TokenMeter-*.zip
ditto -c -k --keepParent "$app" "$zip"

echo "$zip"
codesign -dv "$app" 2>&1 | grep -E 'Authority|TeamIdentifier|Runtime|Signature' || true
