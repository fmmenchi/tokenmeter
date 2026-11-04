#!/bin/sh
# Claude Code status line for tokenmeter (ADR 0002): keeps the latest rate_limits JSON on disk.
# The payload carries the folder and the session of the person, not only the limits: it is readable by them alone.
# One argument, the id of the account's entry, names the file: <id>-statusline.json (ADR 0014); none means claude.
umask 077
dir="$HOME/.tokenmeter"
id="${1:-claude}"
case "$id" in *[!A-Za-z0-9._-]* | "") id=claude ;; esac
mkdir -p "$dir"
input=$(cat)
printf '%s' "$input" > "$dir/$id-statusline.json.tmp" && mv "$dir/$id-statusline.json.tmp" "$dir/$id-statusline.json"
printf 'tokenmeter'
