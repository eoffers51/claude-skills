# Wokwi reference

## diagram.json basics

```json
{
  "version": 1, "author": "<github user>", "editor": "wokwi",
  "parts": [ { "type": "board-esp32-s3-devkitc-1", "id": "esp", "top": 0, "left": 0, "attrs": {} } ],
  "connections": [ [ "esp:TX", "$serialMonitor:RX", "", [] ], [ "esp:RX", "$serialMonitor:TX", "", [] ] ],
  "dependencies": {}
}
```

- A connection is `[from, to, colour, path]`. `from`/`to` are `<partId>:<pin>`.
- `path` is a list of moves from `from`: `"h-25"` (left 25), `"v40"` (down 40). After the last move Wokwi draws the remaining segment to `to` by itself, so end the path **in line** with the target pin (same x or same y) to get a straight last segment.
- Units are diagram units (≈ px at zoom 1). `top`/`left` are the part's top-left corner.
- Wires of the same net may overlap (looks like one wire / a bus); keep different nets apart.
- `"rotate": 90 | 180 | 270` rotates a part, but `pinInfo` stays unrotated: after rotating, read the real positions from a screenshot.

## Part pin offsets (unrotated, relative to the part's top/left)

| Part | type | Pins |
|---|---|---|
| LED | `wokwi-led` (`attrs.color`, `attrs.label`) | `A` (25, 42) anode, `C` (15, 42) cathode - legs at the **bottom**, body above them (~35 tall) |
| Resistor | `wokwi-resistor` (`attrs.value` = "220") | `1` (0, 5.7), `2` (58.8, 5.7) - horizontal |
| Push button | `wokwi-pushbutton` (`attrs.color`, `attrs.label`) | `1.l` (0, 13), `2.l` (0, 32), `1.r` (67, 13), `2.r` (67, 32). `1.l`/`1.r` are the same contact, pressing joins 1 and 2 |
| NeoPixel / WS2812 | `wokwi-neopixel` | `VDD` (1, 3.5), `DIN` (21, 3.5), `VSS` (21, 14), `DOUT`. Works with only `DIN` connected |

### ESP32-S3-DevKitC-1 (`board-esp32-s3-devkitc-1`) pin positions

Board at top 0, left 0. Left header J1 x = 5.1, right header J3 x = 91.4, pitch 9.6.

- J1 (top → bottom): `3V3.1` 29, `3V3.2` 38.6, `RST`, `4`, `5`, `6`, `7`, `15`, `16`, `17`, `18`, `8` 134.6, `3`, `46`, `9` 163.4, `10`, `11`, `12`, `13`, `14`, `5V` 221, `GND.1` 230.6
- J3 (top → bottom): `GND.2` 29, `TX`, `RX`, `1`, `2`, `42`, `41`, `40`, `39`, `38`, `37`, `36`, `35`, `0` 153.8, `45`, `48` 173, `47`, `21`, `20`, `19`, `GND.3` 221, `GND.4` 230.6
- y of pin n on a header = 29 + 9.6 × (index from top).
- Onboard in Wokwi: RGB WS2812 on **GPIO38**, no BOOT/RESET buttons wired.

For any other board, get exact coordinates in the browser (see below) instead of guessing.

## Layout recipe (no wire across a part)

1. Board at (0, 0). Parts for left-header pins go left of the board, right-header pins go right.
2. One row per GPIO: `board pin → resistor → LED`, all on the pin's y.
   - Resistor: `top = pinY - 5.7`; pin `2` near the board (`left = -30 - 58.8` gives pin 2 at x = -30).
   - LED: put its **legs exactly on the row** (`top = pinY - 42`) so the wire enters pin `A` horizontally; the body then sits above the row.
3. LEDs whose bodies would overlap the row above: move them further left (different x columns) or shift that row with a path jog (`["h-25.1", "v-34.6"]` to go up before heading left).
4. Cathodes to GND: drop straight down from `C` to a GND bus below everything (e.g. y = 250), run right to x ≈ -5, then up to `GND.1`: `["v<to 250>", "h<to -5>", "v-19.4"]`. Order the LED columns so these drops don't cross other rows (the LED nearest the board must be the lowest row).
5. Two parts on one pin: join the second one into the first row's wire at a point between resistor and board (same net, overlapping is fine).
6. Right side: button with its `2.l` on the GPIO's y (straight wire), `1.l` routed up to `GND.2`; NeoPixel on its GPIO's y (rotate 180 if needed so `DIN` faces the board).
7. Screenshot, zoom, fix, repeat. The editor re-renders the moment `diagram.json` changes.

## Browser automation (wokwi.com)

All snippets run with the browser's JavaScript tool on a wokwi.com project tab.

**Set a file's contents** (the editor is Monaco, files are `vfs:` models):
```js
const m = monaco.editor.getModels().find(x => x.uri.toString() === 'vfs:diagram.json');
m.setValue(JSON.stringify(DIAGRAM, null, 2));   // also 'vfs:sketch.ino'
```

**Exact pin coordinates of every part**:
```js
const out = {};
document.querySelectorAll('*').forEach(e => { if (e.pinInfo?.length) out[e.tagName.toLowerCase() + '#' + e.id] = e.pinInfo.map(p => `${p.name}@${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' '); });
out
```

**Upload firmware without the native file dialog**: hook the file input, then run the command, then use the file-upload tool on the input that appears.
```js
const orig = HTMLInputElement.prototype.click;
HTMLInputElement.prototype.click = function () {
  if (this.type === 'file') { window.__fw = this; if (!this.isConnected) document.body.appendChild(this); return; }
  return orig.call(this);
};
```
Then: click in the code editor, press `F1`, type `Upload Firmware`, `Return`; `find` "file input" → `file_upload` with the `.bin` path. Remove `window.__fw` from `document.body` afterwards (it shifts the layout). Hooks are lost on reload: re-run before each upload.

**Press a button**:
```js
const press = async (id) => { const el = document.getElementById(id) || document.querySelector('wokwi-pushbutton');
  const t = el.shadowRoot.querySelector('button') || el;
  t.dispatchEvent(new MouseEvent('mousedown', {bubbles: true, composed: true}));
  await new Promise(r => setTimeout(r, 200));
  t.dispatchEvent(new MouseEvent('mouseup', {bubbles: true, composed: true})); window.dispatchEvent(new MouseEvent('mouseup')); };
```

**Read state**:
```js
const leds = {}; document.querySelectorAll('wokwi-led').forEach(l => leds[l.color] = l);   // l.value (bool), l.brightness (0..1)
const px = document.querySelector('wokwi-neopixel');                                       // px.r, px.g, px.b (0..1)
const log = [...document.querySelectorAll('*')].map(e => e.innerText || '').filter(t => t.includes('Mode:')).pop(); // serial monitor text
```
Record transitions over a few seconds (`while (performance.now() - t0 < 3000)` with 5 ms sleeps, push `time + state` when it changes) and compare the periods with the code's timing table.

**Saving**: the **SAVE** button opens a dialog (name + Public/Unlisted). Free plan: only Public. Ask the user first. The URL becomes `https://wokwi.com/projects/<id>`.

## VS Code / CLI

- Extension "Wokwi Simulator": needs `wokwi.toml` + `diagram.json` in the project root, a free licence (it asks), then "Wokwi: Start Simulator".
- `wokwi-cli` (CI): needs `WOKWI_CLI_TOKEN` from https://wokwi.com/dashboard/ci; `wokwi-cli --timeout 5000 --expect-text "Mode:"` runs the firmware headless; GitHub Action `wokwi/wokwi-ci-action@v1`.
