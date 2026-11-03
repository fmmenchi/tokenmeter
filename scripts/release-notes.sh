#!/bin/sh
# Write a clean page of the notes of one version (ADR 0011): the window of an update shows the page the feed points to, so it is not
# the page of the docs site with its menu, but the notes of that version and a link to the whole changelog. The notes are the
# section of that version in docs/use/changelog.md, the one place they are written in.
#   scripts/release-notes.sh [version]     (the MARKETING_VERSION of project.yml by default)
# The page goes to apps/docusaurus/static/release-notes/v<version>.html, which the docs site serves; it must be committed before the
# release is tagged, and deployed (pushed) before the feed is published.
set -eu
cd "$(dirname "$0")/.."

changelog=${CHANGELOG:-docs/use/changelog.md}
out_dir=${OUT_DIR:-apps/docusaurus/static/release-notes}
site=https://fmmenchi.github.io/tokenmeter
version=${1:-$(sed -n "s/^ *MARKETING_VERSION: *'\{0,1\}\([^']*\)'\{0,1\} *\$/\1/p" "${PROJECT_YML:-project.yml}" | head -1)}
[ -n "$version" ] || { echo "No version given and none in project.yml" >&2; exit 1; }

mkdir -p "$out_dir"
CHANGELOG="$changelog" VERSION="$version" SITE="$site" OUT="$out_dir/v$version.html" python3 -I - <<'PY'
import html, os, re, sys

version, site = os.environ["VERSION"], os.environ["SITE"]
lines = open(os.environ["CHANGELOG"], encoding="utf-8").read().split("\n")
start = next((i for i, l in enumerate(lines) if re.match(r"^## " + re.escape(version) + r"( |$)", l)), None)
if start is None:
    sys.exit("No section for " + version + " in " + os.environ["CHANGELOG"])
end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), len(lines))
body = [l for l in lines[start + 1:end]]

def inline(text):
    text = html.escape(text, quote=False)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(r"(?<![\w])_([^_]+)_(?![\w])", r"<em>\1</em>", text)
    def link(m):
        label, target = m.group(1), m.group(2)
        if target.startswith("./") and target.endswith(".md"):
            target = site + "/use/" + target[2:-3]
        # Only an address of the web, with nothing that could close the attribute: anything else stays as the label's text.
        if not re.fullmatch(r"https?://[^\s\"'<>]+", target):
            return label
        return '<a href="' + target + '">' + label + "</a>"
    return re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link, text)

parts, items, para = [], [], []
def flush_items():
    global items
    if items:
        parts.append("<ul>" + "".join("<li>" + inline(" ".join(i)) + "</li>" for i in items) + "</ul>")
        items = []
def flush_para():
    global para
    if para:
        parts.append("<p>" + inline(" ".join(para)) + "</p>")
        para = []
for line in body:
    if line.startswith("- "):
        flush_para(); items.append([line[2:].strip()])
    elif line.startswith("  ") and items:
        items[-1].append(line.strip())
    elif line.strip() == "":
        flush_items(); flush_para()
    else:
        flush_items(); para.append(line.strip())
flush_items(); flush_para()

page = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>tokenmeter %(v)s</title>
<style>
  /* Colours are given for both appearances: the web view of the update window does not always follow the system on its own. */
  :root { color-scheme: light dark; --text: #1d1d1f; --back: #ffffff; --link: #0a60d6; --code: rgba(0, 0, 0, 0.07); }
  @media (prefers-color-scheme: dark) { :root { --text: #f5f5f7; --back: #1e1e1e; --link: #4da3ff; --code: rgba(255, 255, 255, 0.14); } }
  html { background: var(--back); }
  body { font: 13px/1.5 -apple-system, "SF Pro", system-ui, sans-serif; margin: 0; padding: 16px 20px 24px; color: var(--text); background: var(--back); }
  h1 { font-size: 17px; margin: 0 0 8px; }
  p, li { margin: 0 0 8px; }
  ul { padding-left: 20px; margin: 0 0 8px; }
  code { font: 12px ui-monospace, "SF Mono", monospace; padding: 1px 4px; border-radius: 4px; background: var(--code); }
  a { color: var(--link); }
  .all { margin-top: 12px; }
</style>
</head>
<body>
<h1>tokenmeter %(v)s</h1>
%(body)s
<p class="all"><a href="%(site)s/use/changelog">The whole changelog</a></p>
</body>
</html>
""" % {"v": html.escape(version), "body": "\n".join(parts), "site": site}
open(os.environ["OUT"], "w", encoding="utf-8").write(page)
PY
echo "$out_dir/v$version.html"
