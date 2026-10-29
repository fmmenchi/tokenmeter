#!/bin/sh
# Installs the Claude Code status line for tokenmeter (ADR 0019): copies the script to ~/.tokenmeter and
# points `statusLine` in ~/.claude/settings.json at it, only when no other status line is set.
# Exit status: 0 done or already done, 2 another status line is set (left alone), 1 failure.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
dest="$HOME/.tokenmeter/claude-statusline.sh"
settings="$HOME/.claude/settings.json"

mkdir -p "$HOME/.tokenmeter"
cp "$here/claude-statusline.sh" "$dest"
chmod +x "$dest"

if [ ! -f "$settings" ]; then
  mkdir -p "$HOME/.claude"
  printf '{\n  "statusLine": {\n    "type": "command",\n    "command": "%s"\n  }\n}\n' "$dest" > "$settings"
  echo "created $settings with the status line"
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
    print("Wrap it so it also pipes its input to the tokenmeter script: see docs/guides/enable-claude-quota.md")
    sys.exit(2)
else:
    shutil.copy(path, path + ".tokenmeter.bak")
    data["statusLine"] = wanted
    with open(path, "w", encoding="utf-8") as out:
        out.write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print("status line set (backup: settings.json.tokenmeter.bak)")
PY
