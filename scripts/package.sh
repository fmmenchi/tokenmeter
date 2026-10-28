#!/bin/sh
# Build the Release app and zip it into dist/ (ADR 0010).
set -eu
cd "$(dirname "$0")/.."

xcodegen generate -q
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Release \
  -derivedDataPath .build/release -allowProvisioningUpdates build

app=".build/release/Build/Products/Release/TokenMeter.app"
version=$(git describe --tags --always --dirty 2>/dev/null || echo dev)
mkdir -p dist
zip="dist/TokenMeter-$version.zip"
rm -f "$zip"
ditto -c -k --keepParent "$app" "$zip"

echo "$zip"
shasum -a 256 "$zip"
codesign -dv "$app" 2>&1 | grep -E 'Authority|TeamIdentifier|Signature' || true
