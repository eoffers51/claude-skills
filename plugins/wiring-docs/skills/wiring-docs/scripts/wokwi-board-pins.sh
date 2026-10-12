#!/usr/bin/env bash
# Print a Wokwi board's part type, pin names (in header order) and onboard LEDs,
# straight from https://github.com/wokwi/wokwi-boards.
# Usage: wokwi-board-pins.sh <board>      e.g. esp32-s3-devkitc-1, esp32-devkit-v1, esp32-c3-devkitm-1
#        wokwi-board-pins.sh --list       list all board names
set -euo pipefail

base="https://raw.githubusercontent.com/wokwi/wokwi-boards/main/boards"
py="$(command -v python3 || command -v python)"

if [ "${1:-}" = "--list" ] || [ -z "${1:-}" ]; then
    curl -fsSL "https://api.github.com/repos/wokwi/wokwi-boards/contents/boards" |
        "$py" -c "import json,sys; print('\n'.join(d['name'] for d in json.load(sys.stdin)))"
    exit 0
fi

curl -fsSL "$base/$1/board.json" | "$py" -c "
import json, re, sys
# Some board files are JSON5: drop /* */ and // comments and trailing commas
text = re.sub(r'(\"(?:\\\\.|[^\"\\\\])*\")|//[^\n]*|/\*.*?\*/', lambda m: m.group(1) or '', sys.stdin.read(), flags=re.S)
d = json.loads(re.sub(r',(\s*[}\]])', r'\1', text))
print('part type :', 'board-' + sys.argv[1], '(a few classic boards use wokwi-<name> instead, e.g. wokwi-esp32-devkit-v1: check by adding it on wokwi.com)')
print('name      :', d.get('name'), '| mcu:', d.get('mcu'))
pins = d.get('pins', {})
print('pins      :', ' '.join(pins))
for led in d.get('leds', []):
    print('onboard   :', led.get('id'), led.get('type'), led.get('color', ''), 'pins', led.get('pins'))
" "$1"
