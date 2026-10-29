#!/bin/sh
# Notarize the signed zip, staple the ticket and re-zip it (ADR 0021).
# Needs the keychain profile made once with: xcrun notarytool store-credentials tokenmeter-notary
set -eu
cd "$(dirname "$0")/.."

zip=$(ls dist/TokenMeter-*.zip)
profile=tokenmeter-notary

xcrun notarytool submit "$zip" --keychain-profile "$profile" --wait

tmp=$(mktemp -d)
ditto -x -k "$zip" "$tmp"
xcrun stapler staple "$tmp/TokenMeter.app"
spctl --assess --type execute --verbose=2 "$tmp/TokenMeter.app"
rm -f dist/TokenMeter-*.zip
ditto -c -k --keepParent "$tmp/TokenMeter.app" "$zip"
rm -rf "$tmp"

echo "$zip"
shasum -a 256 "$zip"
