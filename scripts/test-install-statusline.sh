#!/bin/sh
# Runs install-statusline.sh against throwaway home directories, never the real one.
set -u
here=$(cd "$(dirname "$0")" && pwd)
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; fail=1; fi; }
run() { HOME="$1" "$here/install-statusline.sh" >"$1/out.txt" 2>&1; echo $?; }
newhome() { mktemp -d; }
cmd() { python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('statusLine',{}).get('command',''))" "$1"; }

h=$(newhome)
check "no settings: exit 0" "$(run "$h")" 0
check "no settings: file created with the status line" "$(cmd "$h/.claude/settings.json")" "$h/.tokenmeter/claude-statusline.sh"
check "script copied and executable" "$([ -x "$h/.tokenmeter/claude-statusline.sh" ] && echo yes)" yes

h=$(newhome); mkdir -p "$h/.claude"
cat > "$h/.claude/settings.json" <<'JSON'
{"model":"sonnet","hooks":{"Stop":[{"hooks":[{"command":"echo \\033"}]}]}}
JSON
check "settings without status line: exit 0" "$(run "$h")" 0
check "status line added" "$(cmd "$h/.claude/settings.json")" "$h/.tokenmeter/claude-statusline.sh"
check "other keys kept" "$(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print(d['model'],d['hooks']['Stop'][0]['hooks'][0]['command'])" "$h/.claude/settings.json")" 'sonnet echo \033'
check "backup written" "$([ -f "$h/.claude/settings.json.tokenmeter.bak" ] && echo yes)" yes
before=$(cat "$h/.claude/settings.json")
check "second run: exit 0" "$(run "$h")" 0
check "second run: file unchanged" "$(cat "$h/.claude/settings.json")" "$before"

h=$(newhome); mkdir -p "$h/.claude"
printf '{"statusLine":{"type":"command","command":"/usr/local/bin/mine"}}' > "$h/.claude/settings.json"
check "other status line: exit 2" "$(run "$h")" 2
check "other status line: left alone" "$(cmd "$h/.claude/settings.json")" /usr/local/bin/mine
check "other status line: no backup made" "$([ -f "$h/.claude/settings.json.tokenmeter.bak" ] && echo yes || echo no)" no

h=$(newhome); mkdir -p "$h/.claude"
printf 'not json' > "$h/.claude/settings.json"
check "invalid settings: exit 1" "$(run "$h")" 1
check "invalid settings: untouched" "$(cat "$h/.claude/settings.json")" "not json"

exit $fail
