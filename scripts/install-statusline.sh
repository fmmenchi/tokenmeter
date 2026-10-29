#!/bin/sh
# Installs the Claude Code status line for tokenmeter (ADR 0019): copies the script to ~/.tokenmeter and
# points `statusLine` in ~/.claude/settings.json at it, only when no other status line is set.
# Without Claude Code (no ~/.claude) there is nothing to set up and nothing is created.
# Exit status: 0 done, already done or nothing to do, 2 another status line is set (left alone), 1 failure.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dest="$HOME/.tokenmeter/claude-statusline.sh"
settings="$HOME/.claude/settings.json"

if [ ! -d "$HOME/.claude" ]; then
  echo "Claude Code not found (no ~/.claude): status line not set up"
  exit 0
fi

mkdir -p "$HOME/.tokenmeter"
cp "$here/claude-statusline.sh" "$dest"
chmod +x "$dest"

if [ ! -f "$settings" ]; then
  printf '{\n  "statusLine": {\n    "type": "command",\n    "command": "%s"\n  }\n}\n' "$dest" > "$settings"
  echo "created $settings with the status line"
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found: set \"statusLine\" to $dest in $settings by hand (docs/use/enable-claude-quota.md)"
  exit 0
fi

python3 - "$settings" "$dest" <<'PY'
import json, shutil, sys

path, command = sys.argv[1:3]
try:
    data = json.load(open(path, encoding="utf-8"))
except ValueError as error:
    sys.exit(f"{path} is not valid JSON, left untouched: {error}")

wanted = {"type": "command", "command": command}
current = data.get("statusLine")
if current == wanted:
    print("status line already set")
elif current is not None:
    print(f"another status line is set ({current.get('command', current)}); left alone.")
    print("Wrap it so it also pipes its input to the tokenmeter script: see docs/use/enable-claude-quota.md")
    sys.exit(2)
else:
    shutil.copy(path, path + ".tokenmeter.bak")
    data["statusLine"] = wanted
    with open(path, "w", encoding="utf-8") as out:
        out.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print("status line set (backup: settings.json.tokenmeter.bak)")
PY
