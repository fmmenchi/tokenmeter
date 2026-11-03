#!/bin/sh
# Claude Code status line for tokenmeter (ADR 0002): keeps the latest rate_limits JSON on disk.
# The payload carries the folder and the session of the person, not only the limits: it is readable by them alone.
umask 077
dir="$HOME/.tokenmeter"
mkdir -p "$dir"
input=$(cat)
printf '%s' "$input" > "$dir/claude-statusline.json.tmp" && mv "$dir/claude-statusline.json.tmp" "$dir/claude-statusline.json"
printf 'tokenmeter'
