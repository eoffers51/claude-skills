---
name: wiring-docs
description: Document the real wiring of an ESP32 / microcontroller project - draw an accurate wiring picture (docs/wiring.svg) for the README, generate a Wokwi simulator circuit (diagram.json + wokwi.toml) from the pins in the code, publish and test it on wokwi.com with the project's own firmware, and add a "Simulate" badge and section to the README. Use when the user asks for a wiring diagram, schematic, circuit picture, "how it's connected" in the README, a Wokwi / online simulator link, or to simulate their board project.
---

# Wiring docs + Wokwi simulator

Turns "what's wired where" into three things that stay in the repo:

| Output | What it is |
|---|---|
| `docs/wiring.svg` | Hand-drawn SVG picture of the real wiring, shown in the README |
| `diagram.json` + `wokwi.toml` | The same circuit for the [Wokwi](https://wokwi.com) simulator (VS Code extension or wokwi.com) |
| README section + badge | Picture, link to the saved Wokwi project, how to load the firmware |

Proven on ESP-IDF v6 / ESP32-S3-DevKitC-1, but the steps work for any board Wokwi supports (ESP32, ESP32-C3/C6/S2/S3, Pico, Arduino...).

## 1. Collect the real wiring (don't guess)

1. Read the code: pin `#define`s in `main/`, `gpio_config` / `pinMode` calls, component `include/*.h` comments, `CLAUDE.md`, `README.md`, `TASK.md`.
2. Things the code can't tell you, ask the user once (one AskUserQuestion with all of them): resistor values, LED polarity / which side goes to GND or 3V3, external vs onboard parts, button wiring (to GND with pull-up?), anything shared on one pin.
3. Write a **wiring table** (part, pin, path to GND/3V3, active level) and confirm it before drawing. Everything below is generated from this table, so the picture, the simulator and the code must all agree.

## 2. Draw `docs/wiring.svg`

Start from `templates/wiring-example.svg` (ESP32-S3-DevKitC-1 with 3 LEDs, onboard RGB, BOOT button) and adapt it:

- Draw the **whole headers in real order** with real labels so a student can count pins on the physical board; highlight only the used pins (gold square + bold white label, no duplicate dim label underneath).
  Header order for the board: from the board's official user guide, or the Wokwi board definition (step 3).
- Parts sit on the side of the header they connect to; wires are orthogonal (`H`/`V` paths), `stroke-width 4`, round caps, one colour per net (3V3 red, GND dark grey, each GPIO its own colour), junction dots where nets split.
- LEDs: triangle pointing anode → cathode + bar; resistors as beige rounded rects with colour bands + value label.
- Onboard parts (RGB LED, BOOT button) are drawn on the board with a dashed callout, not as wires.
- A small table for anything non-obvious (e.g. tri-state pin: HIGH / LOW / input).
- White rounded background rect so it reads on GitHub dark theme; system font stack; no external resources.
- Pin labels on the board must not overlap wires or the edge: wire labels go left of the board with `text-anchor="end"`.

Render and look at it before committing:

```bash
bash <skill-dir>/scripts/render-svg.sh docs/wiring.svg   # writes a PNG next to your scratch dir and prints its path
```
Then Read the PNG and fix overlaps. In the README, put the picture under the wiring heading and keep any old ASCII diagram in a `<details><summary>Text version</summary>` block.

## 3. Generate the Wokwi circuit

1. Board part type and pin names come from Wokwi's board definition, not memory:
   ```bash
   bash <skill-dir>/scripts/wokwi-board-pins.sh esp32-s3-devkitc-1   # also: esp32-devkit-v1, esp32-c3-devkitm-1, ...
   ```
   It prints the part type (`board-<name>`), all pin names (`3V3.1`, `GND.1`, `8`, ...), and the onboard LEDs with their GPIOs.
2. **Onboard parts that differ from the user's board** must be added as external parts on the real pin. Known case: Wokwi's ESP32-S3-DevKitC-1 has its RGB LED on **GPIO38** and no simulated BOOT button. A v1.0 / clone board uses **GPIO48**, so add a `wokwi-neopixel` on 48 and a `wokwi-pushbutton` on GPIO0 to GND.
3. Write `diagram.json` using `templates/diagram-example.json` and `reference/wokwi.md` (part pin offsets, wire path syntax, layout recipe so no wire crosses a part). Keep the serial monitor connections (`esp:TX`/`esp:RX` to `$serialMonitor`).
4. Write `wokwi.toml` for the VS Code extension:
   - ESP-IDF: `firmware = 'build/flasher_args.json'`, `elf = 'build/<project>.elf'` (project name from top-level `CMakeLists.txt`).
   - PlatformIO: `.pio/build/<env>/firmware.bin` / `.elf`.
5. Add one line to `CLAUDE.md` (if it exists): wiring lives in `docs/wiring.svg` and `diagram.json`, so update both when a pin changes.

## 4. Publish and test on wokwi.com (browser)

Needs Claude in Chrome (or the built-in browser) and the user signed in to wokwi.com. Read `reference/wokwi.md` → "Browser automation" for the exact JS snippets.

1. **Firmware**: wokwi.com cannot compile ESP-IDF (its online compiler is Arduino only). It runs a binary you upload:
   - ESP-IDF: `idf.py build merge-bin` → `build/merged-binary.bin`, or the CI artifact / release `*-merged.bin` (`gh run download <id> -n <artifact>` puts it under `build/`).
   - Arduino projects can paste the sketch instead.
2. Open `https://wokwi.com/projects/new/<board>` (e.g. `esp32-s3`), set `diagram.json` through the Monaco model (`vfs:diagram.json`), screenshot, and fix the layout until no wire runs across a part.
3. Replace `sketch.ino` with a comment: link to the GitHub repo, "ESP-IDF can't be compiled here: press F1 → Upload Firmware and Start Simulation… and pick `<name>-merged.bin` from the latest release". Otherwise pressing ▶ runs the default Arduino blink.
4. Upload the firmware (F1 → "Upload Firmware and Start Simulation…" - hook the hidden file input first, see reference) and **test every mode** by reading part state from JS (`wokwi-led.value/brightness`, `wokwi-neopixel.r/g/b`, serial log text) and pressing buttons with mouse events. Report what passed.
5. **Ask before saving** (it publishes): name the project; on the free plan only **Public** works (Unlisted needs a paid plan). After saving, reload the URL and check the diagram and note survived. The uploaded firmware is *not* saved with the project; everyone uploads it once.

## 5. README

Use `templates/readme-section.md`: a `simulate-Wokwi` badge next to the other badges, the picture, and a "Simulate in Wokwi" section (browser steps with the release link, VS Code steps, board differences, simulator quirks). Then commit (only when asked) and check the rendered README on GitHub.

## Wokwi gotchas (check these before reporting a "bug")

- **LED smoothing**: Wokwi blends LED brightness over ~100 ms, so on/off gaps shorter than that (e.g. a 60 ms double flash) look like one flash. Measure the period from `led.value` changes instead; the firmware is usually fine.
- **Floating pin**: a GPIO switched to input really leaves LEDs dark (tri-state tricks work).
- `wokwi.toml` with `flasher_args.json` needs `idf.py build` first; the merged bin for wokwi.com needs `idf.py merge-bin`.
- Default flash in Wokwi is 4 MB; set `"attrs": {"flashSize": "16"}` on the board if the app needs more.
- USB-Serial-JTAG console: set `"serialInterface": "USB_SERIAL_JTAG"` on the board and drop the `$serialMonitor` connections.
