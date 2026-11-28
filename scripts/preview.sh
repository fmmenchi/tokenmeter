#!/bin/sh
# Builds the checked-out branch and opens it without installing it, so a change can be tried before it is merged.
# It quits the running TokenMeter first, installed or not: two gauge icons in the menu bar would be confusing. The copy in
# /Applications is not touched; open it again to go back.
#
# The build is copied to ~/Applications and opened from there, so its widget shows in Edit Widgets: chronod ignores an
# extension whose app sits in a hidden folder such as .build, and two registered copies of the same extension hide both.
set -eu
cd "$(dirname "$0")/.."

LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
BUILT=.build/xcode/Build/Products/Debug/TokenMeter.app
PREVIEW="$HOME/Applications/TokenMeter.app"

xcodegen generate -q
# macOS refuses to change an app bundle that has run ("Operation not permitted"), but lets it be deleted: start clean.
rm -rf "$BUILT"
xcodebuild -project TokenMeter.xcodeproj -scheme TokenMeter -configuration Debug \
  -derivedDataPath .build/xcode -allowProvisioningUpdates -quiet build
pkill -x TokenMeter || true
# open fails with -600 if the old process is still going away.
while pgrep -x TokenMeter >/dev/null; do sleep 0.2; done

# The build product stays unregistered, so only the copy in ~/Applications offers the widget.
pluginkit -r "$BUILT/Contents/PlugIns/TokenMeterWidget.appex" 2>/dev/null || true
"$LSREGISTER" -u "$BUILT" 2>/dev/null || true

mkdir -p "$HOME/Applications"
rm -rf "$PREVIEW"
ditto "$BUILT" "$PREVIEW"
"$LSREGISTER" -f -R "$PREVIEW"
pluginkit -a "$PREVIEW/Contents/PlugIns/TokenMeterWidget.appex"
open "$PREVIEW"
echo "Opened $PREVIEW. To go back: quit it, delete it and open /Applications/TokenMeter.app."
