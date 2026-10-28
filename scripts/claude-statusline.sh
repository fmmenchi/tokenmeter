#!/bin/sh
# Claude Code status line for tokenmeter (ADR 0005): keeps the latest rate_limits JSON on disk.
dir="$HOME/.tokenmeter"
mkdir -p "$dir"
input=$(cat)
printf '%s' "$input" > "$dir/claude-statusline.json.tmp" && mv "$dir/claude-statusline.json.tmp" "$dir/claude-statusline.json"
printf 'tokenmeter'
