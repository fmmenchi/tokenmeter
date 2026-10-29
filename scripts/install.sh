#!/bin/sh
# Builds the app, installs it in /Applications and sets up the Claude status line (ADR 0010, 0019).
set -eu
cd "$(dirname "$0")/.."

./scripts/package.sh
pkill -x TokenMeter || true
tmp=$(mktemp -d)
ditto -x -k dist/TokenMeter-*.zip "$tmp"
ditto "$tmp/TokenMeter.app" /Applications/TokenMeter.app
rm -rf "$tmp"

# Status 2 means another status line is already set: report it, but the app is installed.
status=0
./scripts/install-statusline.sh || status=$?
open /Applications/TokenMeter.app
exit $((status == 2 ? 0 : status))
