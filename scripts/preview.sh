#!/bin/sh
# Builds the checked-out branch and opens it without installing it, so a change can be tried before it is merged.
# It quits the running TokenMeter first, installed or not: two gauge icons in the menu bar would be confusing. The copy in
# /Applications is not touched; open it again to go back.
set -eu
cd "$(dirname "$0")/.."

xcodegen generate -q
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Debug \
  -derivedDataPath .build/xcode -allowProvisioningUpdates -quiet build
pkill -x TokenMeter || true
# open fails with -600 if the old process is still going away.
while pgrep -x TokenMeter >/dev/null; do sleep 0.2; done
open .build/xcode/Build/Products/Debug/TokenMeter.app
