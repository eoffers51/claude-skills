---
name: wiring-docs
description: Document the real wiring of an ESP32 / microcontroller project - draw an accurate wiring picture (docs/wiring.svg) for the README, generate a Wokwi simulator circuit (diagram.json + wokwi.toml) from the pins in the code, publish it on wokwi.com as a project that runs the repo's own code on one click (and test every mode), and add a "Simulate" badge and section to the README. Use when the user asks for a wiring diagram, schematic, circuit picture, "how it's connected" in the README, a Wokwi / online simulator link, or to simulate their board project.
---

# Wiring docs + Wokwi simulator

Turns "what's wired where" into three things that stay in the repo:

| Output | What it is |
|---|---|
| `docs/wiring.svg` | Hand-drawn SVG picture of the real wiring, shown in the README |
| `diagram.json` + `wokwi.toml` | The same circuit for the [Wokwi](https://wokwi.com) simulator (VS Code extension or wokwi.com) |
| `wokwi/` | Wokwi-only glue files so the repo's code compiles on wokwi.com (Arduino-core build) |
| README section + badge | Picture and a link to a saved Wokwi project that runs on ▶ |

Proven on ESP-IDF v6 / ESP32-S3-DevKitC-1, but the steps work for any board Wokwi supports (ESP32, ESP32-C3/C6/S2/S3, Pico, Arduino...).

## 1. Collect the real wiring (don't guess)

1. Read the code: pin `#define`s in `main/`, `gpio_config` / `pinMode` calls, component `include/*.h` comments, `CLAUDE.md`, `README.md`, `TASK.md`.
2. Things the code can't tell you, ask the user once (one AskUserQuestion with all of them): **exact board model / revision** (the code only shows the chip, e.g. `esp32s3`; clones differ, e.g. RGB LED on GPIO48 vs 38), resistor values, LED polarity / which side goes to GND or 3V3, external vs onboard parts, button wiring (to GND with pull-up?), anything shared on one pin.
3. Write a **wiring table** (part, pin, path to GND/3V3, active level) and confirm it before drawing. Everything below is generated from this table, so the picture, the simulator and the code must all agree.

## 2. Draw `docs/wiring.svg`

Start from `templates/wiring-example.svg` (ESP32-S3-DevKitC-1 with 3 LEDs, onboard RGB, BOOT button) and adapt it. Every block is marked with an XML comment (`Board`, `used pins highlighted`, `Wires`, `Resistors`, `LEDs`, `Callouts`, truth table): delete what the project doesn't use, and when a pin stops being highlighted put its dim label back in the header row. For another board, redraw the board block from the header order.

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

**Goal: the shared link must run on ▶ with no upload.** An uploaded `.bin` is *not* saved with a Wokwi project, so a project that needs one looks broken to everyone who opens the README link. Put the project's **source code** in the Wokwi project instead:

1. **Make the code compile on wokwi.com.** Wokwi builds ESP-IDF code with the **Arduino ESP32 core** (3.x, on ESP-IDF 5.x). Plain ESP-IDF APIs (`driver/gpio.h`, FreeRTOS, `esp_log.h`, `esp_err.h`) work unchanged. Two things don't, so add Wokwi-only files in a repo folder `wokwi/` (templates in `templates/wokwi/`):
   - **`app_main` clash**: the core already defines `app_main()` → link error "multiple definition of `app_main`". Upload a copy of `main/main.c` with `#define app_main <project>_app_main` as its first code line (generate it under `build/`, which is git-ignored, don't commit a second main.c), plus `sketch.ino` whose `setup()` calls `<project>_app_main()` (`extern "C"`).
   - **Registry components** (`managed_components/`, e.g. `espressif/led_strip`) aren't available. Write a Wokwi-only `.c` with the same header API using core functions (WS2812: `rgbLedWrite(pin, r, g, b)`; see `templates/wokwi/led.c`).
   - Also: `ESP_LOGI` output is hidden (Arduino log level), so don't rely on log lines in Wokwi. Read LED state instead. Mention this in the README.
   - Arduino projects: just use the sketch and its files.
2. **Build the project in the browser**: open `https://wokwi.com/projects/new/<board>` (e.g. `esp32-s3`). **Click the `diagram.json` tab first** (its Monaco model only exists after it's been opened), then set `diagram.json` and `sketch.ino` through their models. **Never rename** the default `sketch.ino`: a renamed file keeps the old model, and a new file with the old name then wipes it (Wokwi bug).
3. **Add the source files**: file menu ▾ → *Upload file(s)…* takes many files at once (flat names: `components/x/include/x.h` → `x.h`). Install the file-input hook first (see reference), then use the file-upload tool. It can only read files inside the session's folders.
4. **Press ▶ and test every mode** by reading part state from JS (`wokwi-led.value`, `wokwi-neopixel.r/g/b`) and pressing buttons with mouse events. The free build queue can take 1–3 min, and "Build Servers Busy" means retry (save first so nothing is lost), not a code error. A compile error shows in a "Build failed!" dialog; read it with `document.body.innerText`.
5. **Ask before saving** (it publishes): on the free plan only **Public** works (Unlisted needs a paid plan). After saving, reload the URL and check that every file is there.
6. **Optional, the real firmware**: F1 → "Upload Firmware and Start Simulation…" runs a `.bin` (`idf.py build merge-bin` → `build/merged-binary.bin`, or a CI artifact / release) for a one-off check. Good for testing, useless for sharing.
7. If the user wants an old Wokwi project deleted, they do it themselves (dashboard → ⋮ → Delete). Closing a tab with unsaved Wokwi changes shows a native "Leave site?" prompt the browser tools can't click: save or ask the user.

## 5. README

Use `templates/readme-section.md`: a `simulate-Wokwi` badge next to the other badges, the picture, and a "Simulate in Wokwi" section ("open and press ▶", what `wokwi/` contains, VS Code steps, board differences, simulator quirks). Add `templates/wokwi/README.md` as `wokwi/README.md` (which Wokwi file comes from where, how to re-sync after code changes). Then commit (only when asked) and check the rendered README on GitHub.

## Wokwi gotchas (check these before reporting a "bug")

- **LED smoothing**: Wokwi blends LED brightness over ~100 ms, so on/off gaps shorter than that (e.g. a 60 ms double flash) look like one flash. Measure the period from `led.value` changes instead; the firmware is usually fine.
- **Floating pin**: a GPIO switched to input really leaves LEDs dark (tri-state tricks work).
- `wokwi.toml` with `flasher_args.json` needs `idf.py build` first; a merged bin for a one-off upload needs `idf.py merge-bin`.
- Shared project "does nothing" on ▶: it has no source (only a placeholder sketch). Firmware uploads aren't saved; put the code in the project (step 4).
- Default flash in Wokwi is 4 MB; set `"attrs": {"flashSize": "16"}` on the board if the app needs more.
- USB-Serial-JTAG console: set `"serialInterface": "USB_SERIAL_JTAG"` on the board and drop the `$serialMonitor` connections.
