---
name: sysview-trace
description: Add SEGGER SystemView tracing to any ESP-IDF v6 FreeRTOS project and show the user a timeline of which task runs when - live over the board's USB-UART (COM port) through a small bridge, or recorded over JTAG to a file. Covers the esp_sysview component, the sdkconfig fragments, the encoder-name and linker fixes, a separate build folder that leaves the normal build untouched, SystemView setup on Windows, and how to read the result (activations, CPU load, run/blocked time, tick). Use when the user asks to "trace", "visualize task execution", "see the tasks / scheduler / context switches", "task timeline", "CPU load per task", "runtime of my tasks", "SystemView" or "SEGGER" on an ESP32 project.
---

# SystemView tracing for ESP-IDF projects

Adds [SEGGER SystemView](https://www.segger.com/products/development-tools/systemview/) to a project without touching its normal build. The trace firmware is built in its own folder from the project's own sources plus one sdkconfig fragment, so `idf.py build` keeps producing the normal firmware.

| Mode | How the user sees it | Cable | Cores | Serial log | Use when |
|---|---|---|---|---|---|
| **Live (UART)**, default | Timeline scrolls live in SystemView | The board's USB-UART port only | One (the build runs FreeRTOS on core 0) | Off: the port carries the trace | Teaching, "watch my tasks run" |
| **Record (JTAG)** | Record N seconds to a `.SVDat` file, then load it | USB-UART for flashing + a JTAG link (ESP32-S3/C3/C6/H2/P4: the chip's built-in USB-JTAG on the native USB port) | All | Still on the UART | Dual-core behaviour, lower overhead, long captures |

Proven on ESP-IDF v6.0.2, ESP32-S3-DevKitC-1 clone (CH343 USB-UART), `espressif/esp_sysview` 1.0.2, SystemView V4.10b on Windows. For ESP-IDF v5.x SystemView is built into `app_trace` with different options: follow `examples/system/sysview_tracing` of that IDF version instead.

## 0. Check before starting

1. ESP-IDF version: `idf.py --version`. This skill is for v6.x (SystemView is the managed component `espressif/esp_sysview`).
2. The project uses FreeRTOS tasks (anything does; a superloop shows one `main` task, which is still a useful lesson).
3. SystemView is installed on the PC (free for non-commercial use). Note its version: one `.SVDat` with both cores needs 3.60+.
4. Pick the mode with the user (table above). Live is the default for a board with a USB-UART bridge chip. A board whose only USB port is the chip's native USB (no UART bridge) can't do live UART over that cable: use JTAG mode.
5. Find the chip's UART0 pins (live mode). They are fixed per chip and wired to the USB-UART bridge on DevKits:

   | Chip | TX | RX |
   |---|---|---|
   | ESP32 | 1 | 3 |
   | ESP32-S2 / S3 | 43 | 44 |
   | ESP32-C3 | 21 | 20 |
   | ESP32-C6 | 16 | 17 |
   | ESP32-H2 | 24 | 23 |
   | ESP32-P4 | 37 | 38 |

   Other chips: `grep U0TXD_GPIO_NUM $IDF_PATH/components/soc/<chip>/include/soc/uart_pins.h`.

## 1. Add the component (only for trace builds)

Copy `templates/idf_component.yml` to the app component, usually `main/idf_component.yml` (merge the `espressif/esp_sysview` entry into an existing file). The `rules:` line makes the component manager download it **only** when the trace build turns the external trace library on, so normal builds stay offline and unchanged.

Version pin: `~1.0.2` for IDF v6.0.x. `esp_sysview` 1.1.x expects a newer `esp_trace` API (an encoder `flush` hook) and fails to compile on v6.0.x with `'esp_trace_encoder_vtable_t' has no member named 'flush'`. On a newer IDF try `^1` first and fall back to `~1.0.2` on that error.

## 2. Tell esp_trace which encoder to open

Copy `templates/trace_params.c` next to the app sources (e.g. `main/trace_params.c`) and add the snippet from `templates/main-CMakeLists.snippet.cmake` to that component's `CMakeLists.txt`. It adds the file, `esp_trace` and `WHOLE_ARCHIVE` only when `CONFIG_ESP_TRACE_LIB_EXTERNAL` is set.

Why both are needed:
- IDF's default `esp_trace_get_user_params()` asks for the encoder `"ext"`, but `esp_sysview` registers itself as `"sysview"`. Without the override the firmware **aborts at boot**: `E esp_trace_core: Encoder 'ext' or transport 'apptrace' not found` then `init function ... has failed (0x105), aborting`. IDF's own `sysview_tracing` example does the same override.
- The default is a *weak* function inside `libesp_trace.a`, so nothing is "undefined" and the linker never pulls `trace_params.c.obj` out of `libmain.a`. `-u esp_trace_get_user_params` doesn't help either (link order). `WHOLE_ARCHIVE` links every object of the component, so the strong definition wins. Check in the map file: `esp_trace_get_user_params ... libmain.a(trace_params.c.obj)`.

If the project's `main` is a single file, putting the function in that file (guarded by `#if CONFIG_ESP_TRACE_LIB_EXTERNAL`) also works and needs no `WHOLE_ARCHIVE`, but it mixes trace glue into the student's code. Prefer the separate file.

## 3. The sdkconfig fragment

Copy one template to the project root:
- live: `templates/sdkconfig.sysview_uart`. **Set `CONFIG_IDF_TARGET` and `CONFIG_APPTRACE_UART_TX_GPIO` / `RX_GPIO` to the chip and its UART0 pins** (table in step 0).
- record: `templates/sdkconfig.sysview_jtag` (set `CONFIG_IDF_TARGET`).

What the live fragment does and why:
- `ESP_TRACE_ENABLE` + `ESP_TRACE_TRANSPORT_APPTRACE` + `ESP_TRACE_LIB_EXTERNAL`: tracing on, through apptrace, with the SystemView library from the component.
- `APPTRACE_DEST_UART`, UART0 at 1 Mbaud on the UART0 pins: the trace goes out of the same port the board is flashed through.
- `ESP_CONSOLE_NONE`: UART0 now belongs to the trace.
- `LOG_DEFAULT_LEVEL_NONE` and `BOOTLOADER_LOG_LEVEL_NONE`: with no console the log goes nowhere, but `ESP_LOGx` would still format every line and take the log lock. In SystemView that appears as `xQueueGenericSend/Receive` inside the user's tasks and makes a trivial task run take about 1 ms.
- `FREERTOS_UNICORE`: over UART SystemView traces one core. Running everything on core 0 means no task is missing from the view. (Alternative for dual-core apps: keep both cores and pick the traced CPU in *SEGGER SystemView Configuration*; tasks on the other core are then invisible.)
- `SEGGER_SYSVIEW_EVT_*`: task start/stop/ready, ISR enter/exit, idle, timers.

These options belong to the component, so they only exist after it is downloaded. The first build prints `unknown kconfig symbol 'SEGGER_SYSVIEW_EVT_...'` while it downloads the component. Usually it then re-configures and finishes by itself; if it stops with *"Re-run the build process"* (exit code 255), run the same command again.

The fragment also sets `CONFIG_IDF_TARGET`: a fresh clone has no root `sdkconfig`, and the trace folder would otherwise default to plain `esp32`.

## 4. Build in its own folder

Compose the project's own defaults (if any) with the fragment, in a separate build folder:

```powershell
idf.py -B build_live -D SDKCONFIG=build_live/sdkconfig -D "SDKCONFIG_DEFAULTS=sdkconfig.defaults;sdkconfig.sysview_uart" build
idf.py -B build_live -D SDKCONFIG=build_live/sdkconfig -D "SDKCONFIG_DEFAULTS=sdkconfig.defaults;sdkconfig.sysview_uart" -p COM5 flash
```

- Repeat **both `-D` options on every `idf.py` call** for that folder, including `flash`. With `-B` alone, `idf.py` silently uses the root `sdkconfig` and builds the normal firmware.
- Leave out `sdkconfig.defaults` if the project has none; list any other defaults files the project needs (e.g. a solution-select fragment) before the trace fragment.
- Changing the fragment later: delete `build_live/sdkconfig` first. Defaults are only applied to options not yet in that file.
- Add `build_live/` (and `build_trace/`) to `.gitignore`.
- Several build folders in one project: keep one component-manager lock per folder, or the builds rewrite each other's `dependencies.lock`. In the root `CMakeLists.txt`, between `include(.../project.cmake)` and `project(...)`:

  ```cmake
  idf_build_set_property(DEPENDENCIES_LOCK "${CMAKE_BINARY_DIR}/dependencies.lock")
  ```

  The normal build still removes the unused component from `managed_components/`; the next trace build re-fetches it from the local cache.

Verify before flashing: `CONFIG_ESP_TRACE_LIB_EXTERNAL=y` and the APPTRACE/console lines are in `build_live/sdkconfig`, and the map file shows `SEGGER_SYSVIEW_Start` and `trace_params.c.obj`.

## 5. SystemView on the PC (once)

ESP-IDF numbers the FreeRTOS events its own way. Replace SystemView's FreeRTOS description file with IDF's, keeping a backup. Administrator PowerShell:

```powershell
$d = "C:\Program Files\SEGGER\SystemView\Description"
Copy-Item "$d\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt.segger-original"
Copy-Item "$env:IDF_PATH\tools\esp_app_trace\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt" -Force
```

`Program Files` needs elevation. If the agent can't elevate, give the user this block to run.

## 6a. Live: run the bridge

SystemView's own **UART** recorder stops with *"Error while recording. Recorder stopped."*: it starts with a hello handshake and ESP-IDF's UART transport doesn't answer it (the board itself is fine). `scripts/sysview_bridge.py` answers the hello, then copies bytes both ways between SystemView's **IP** recorder and the COM port, and resets the board (RTS pulse) for every recording so SystemView always gets the system description and task list first.

Copy it into the project (`tools/sysview_bridge.py`) and run it with the IDF Python (it needs `pyserial`):

```powershell
python tools/sysview_bridge.py --port COM5
```

In SystemView: *Target → Recorder Configuration* → **IP**, `127.0.0.1`, port `19111`, then *Target → Start Recording* (`F5`). The bridge prints what SystemView sends and how much it streamed. It holds the COM port until `Ctrl+C`: stop it before flashing anything.

Check without SystemView (useful when debugging): with the firmware freshly reset, COM5 at 1 Mbaud is silent; after sending one byte `0x01` (SystemView's START command) it streams binary data containing the task names.

## 6b. Record: JTAG

Run `scripts/sysview_capture.ps1` from the project root in a PowerShell with the IDF environment active. It builds and flashes the trace folder over the UART port, starts OpenOCD with the board config, records N seconds from all cores with `esp sysview_mcore` into one `.SVDat`, and shuts OpenOCD down:

```powershell
.\tools\sysview_capture.ps1 -Port COM5 -Seconds 5 -BuildDir build_trace -Defaults "sdkconfig.defaults;sdkconfig.sysview_jtag" -OpenOcdCfg board/esp32s3-builtin.cfg
```

Then in SystemView: **File → Load Data** (`Ctrl+O`). SystemView ignores a file given on its command line and opens an empty *New Recording*.

Windows, built-in USB-JTAG only: if OpenOCD says `libusb_open() failed with LIBUSB_ERROR_NOT_FOUND`, the *USB JTAG/serial debug unit* is bound to Microsoft's generic WinUSB without a device interface GUID. Install Espressif's driver (ESP-IDF guide *Configure ESP32-S3 Built-in JTAG Interface*), administrator PowerShell, then unplug/replug the native USB cable (or remove the device in Device Manager and scan for changes):

```powershell
Invoke-WebRequest 'https://dl.espressif.com/dl/idf-env/idf-env.exe' -OutFile .\idf-env.exe; .\idf-env.exe driver install --espressif
```

The device must then show driver provider `libwdi`, not `Microsoft`.

## 7. Reading the result (teach this)

- **Context window** lists every interrupt the chip has (from the system description), most with 0 activations. Sort by **Activations** (click the header): the user's tasks, `Idle`, `Scheduler` and the tick come first. Untick rows to hide them from the timeline.
- **The tick** is two nested rows: the hardware timer interrupt (`SYSTIMER_TARGET0` on S3/C3/C6...) with FreeRTOS's `SysTick` handler inside it, `CONFIG_FREERTOS_HZ` times per second.
- **Check periodic tasks with Activations**: activations ≈ recording time / period. Example from a 3-LED lesson (200/500/1000 ms, 22.5 s): 113 / 45 / 22, a 5 : 2 : 1 ratio, `Idle` 96 % CPU.
- **Timeline**: zoom out until the window is longer than the slowest period. At the default few-ms zoom a 200 ms task looks "empty"; that is the zoom, not the trace. Double-click an event in the Events list to jump to it.
- **Durations include tracing overhead.** Over UART every event is pushed out at 1 Mbaud, so a GPIO-toggle task shows about 0.2 ms and the tick about 0.1 ms, where the real work is a few µs. Intervals and counts are exact; absolute run times are inflated (less so over JTAG).
- `FROM_CPU_INTR0` around task switches is the cross-core / yield interrupt FreeRTOS uses; it's normal.

## 8. Clean up and hand back

- Flash the normal firmware again (`idf.py -p COM5 flash`) so the serial log is back.
- Keep in the repo: the fragment, `trace_params.c`, the CMake snippet, `idf_component.yml`, the bridge (and the capture script if JTAG is used), plus a README section with the two commands and the SystemView steps. Never commit `build_live/`, `build_trace/`, `.SVDat` files or `managed_components/`.

More symptoms and fixes: `reference/troubleshooting.md`. A checklist for people (same steps, copy-paste commands): `README.md`.
