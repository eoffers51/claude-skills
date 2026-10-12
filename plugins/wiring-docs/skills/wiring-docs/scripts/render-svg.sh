#!/usr/bin/env bash
# Render an SVG to PNG with headless Chrome/Edge/Chromium so you can look at it.
# Usage: render-svg.sh <file.svg> [out.png] [width] [height]
# Width/height default to the SVG's width/height attributes (or 800x600).
set -euo pipefail

svg="${1:?usage: render-svg.sh <file.svg> [out.png] [width] [height]}"
out="${2:-${TMPDIR:-${TEMP:-/tmp}}/$(basename "${svg%.*}").png}"

# Size from the root <svg width=".." height="..">
w="${3:-$(grep -o '<svg[^>]*' "$svg" | grep -o ' width="[0-9]*' | grep -o '[0-9]*' | head -1 || true)}"
h="${4:-$(grep -o '<svg[^>]*' "$svg" | grep -o ' height="[0-9]*' | grep -o '[0-9]*' | head -1 || true)}"
w="${w:-800}"; h="${h:-600}"

# Find a Chromium-based browser
browser=""
for c in \
    "/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
    "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then browser="$c"; break; fi
done
[ -n "$browser" ] || { echo "No Chrome/Edge/Chromium found" >&2; exit 1; }

# Absolute file:// URL (Git Bash paths like /d/x -> D:/x)
abs="$(cd "$(dirname "$svg")" && pwd)/$(basename "$svg")"
if command -v cygpath >/dev/null 2>&1; then
    abs="$(cygpath -m "$abs")"; out_native="$(cygpath -m "$out")"
else
    out_native="$out"
fi
case "$abs" in /*) url="file://$abs" ;; *) url="file:///$abs" ;; esac

profile="$(mktemp -d)"
"$browser" --headless=new --disable-gpu --hide-scrollbars --window-size="$w,$h" \
    --user-data-dir="$profile" --screenshot="$out_native" "$url" >/dev/null 2>&1 || true
rm -rf "$profile" 2>/dev/null || true

[ -s "$out" ] || { echo "Render failed" >&2; exit 1; }
echo "$out"
