---
name: sysview-trace
description: Record a SEGGER SystemView trace of any ESP-IDF v6 FreeRTOS project over JTAG, using only Espressif's and SEGGER's own tooling (espressif/esp_sysview component, esp_trace apptrace, OpenOCD `esp sysview_mcore`, SystemView), in a separate build folder that leaves the normal build untouched, and show the user the timeline of which task runs when (activations, CPU load, run/blocked time, tick). Use when the user asks to "trace", "visualize task execution", "see the tasks / scheduler / context switches", "task timeline", "CPU load per task", "runtime of my tasks", "SystemView" or "SEGGER" on an ESP32 project.
---

# SystemView tracing for ESP-IDF projects

Records a [SEGGER SystemView](https://www.segger.com/products/development-tools/systemview/) trace of a FreeRTOS project exactly the way Espressif documents it, without touching the project's normal build. The trace firmware is built in its own folder from the project's own sources plus one sdkconfig fragment, so `idf.py build` keeps producing the normal firmware.

```
sdkconfig.sysview_jtag  ->  idf.py @sysview_jtag.args build/flash  ->  OpenOCD + gdb (esp sysview_mcore start/stop)  ->  trace.SVDat  ->  SystemView: File > Load Data
```

Everything here is provider tooling used as its documentation shows: the managed component `espressif/esp_sysview`, the `esp_trace` apptrace transport over JTAG, OpenOCD's `esp sysview_mcore` command, GDB to start and stop the recording at the right moment, and SystemView to read the file. The only code added to the project is the `esp_trace_get_user_params()` function from Espressif's own `sysview_tracing` example, pasted into the main source file.

Upstream references: [System Behavior Analysis with SEGGER SystemView](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/tracing/sysview.html) (v6.0/v6.1: `docs/en/api-guides/app_trace.rst`), the [tracing overview](https://docs.espressif.com/projects/esp-idf/en/latest/esp32s3/api-guides/tracing/index.html), and the example `examples/system/sysview_tracing` (`examples/system/tracing/sysview_tracing` on master).

Proven on ESP-IDF v6.0.2, ESP32-S3-DevKitC-1 clone (built-in USB-JTAG on the native USB port, CH343 USB-UART for flashing), `espressif/esp_sysview` 1.0.2, SystemView V4.10b on Windows. For ESP-IDF v5.x SystemView is built into `app_trace` with different options: follow `examples/system/sysview_tracing` of that IDF version instead.

## What this skill deliberately does not do

- **No live view.** Espressif's guide says events can be viewed in real time over UART (and, from v6.1, over the chip's USB-Serial-JTAG), but SystemView's UART recorder expects SEGGER's 4-byte target hello (`SEGGER_UART.c` in the SystemView target sources) and `esp_sysview` (1.0.x, 1.1.x) never sends it: the recorder stops with *"Error while recording. Recorder stopped."* (seen on hardware). Making it work needs either a host-side bridge program or a change in `esp_sysview`; both are custom code, so they are not part of this skill. If the user needs a live timeline, say so plainly and point to the `esp_sysview` component's issue tracker. Recording over JTAG covers the same questions (which task runs when, how often, how long) a few seconds later, for all cores, with lower overhead.
- **No wrapper scripts.** `idf.py`, `openocd` and `gdb` are used directly, as in the example README.
- **No CMake changes.** The function goes into the main source file, as in the example, so no `WHOLE_ARCHIVE` or extra requirements are needed.

## 0. Check before starting

1. ESP-IDF version: `idf.py --version`. This skill is for v6.x (SystemView is the managed component `espressif/esp_sysview`). The component version depends on the IDF minor (step 1).
2. The project uses FreeRTOS tasks (anything does; a superloop shows one `main` task, which is still a useful lesson).
3. SystemView is installed on the PC (free for non-commercial use), version **3.60 or newer** (`esp sysview_mcore` writes SEGGER's multi-core format into one file).
4. A JTAG link. ESP32-S3/C3/C5/C6/H2/P4: the chip's built-in USB-JTAG on the board's **native USB** port, OpenOCD config `board/<chip>-builtin.cfg`. Plain ESP32/S2: an external probe (ESP-Prog, ESP-WROVER-KIT, `board/esp32-wrover-kit-3.3v.cfg`). Connect the USB-UART port too: it flashes the board and keeps showing the serial log.
5. Windows, built-in USB-JTAG only: the device must use Espressif's driver (step 6 has the fix if OpenOCD cannot open it).

## 1. Add the component (only for trace builds)

Copy `templates/idf_component.yml` to the app component, usually `main/idf_component.yml` (merge the `espressif/esp_sysview` entry into an existing file). The `rules:` line, a standard component-manager feature, makes the download happen **only** when the trace build turns the external trace library on, so normal builds stay offline and unchanged.

Version rule (the registry says `idf >=6.0` for every version, which is not the whole story):

| ESP-IDF | `espressif/esp_sysview` | Why |
|---|---|---|
| v6.0.x | `"~1.0.2"` | 1.1.x calls the encoder `flush` hook that `esp_trace` only has from v6.1. On v6.0.x it fails with `'esp_trace_encoder_vtable_t' has no member named 'flush'`. |
| v6.1 and later | `"^1.1"` (what the guide shows as `^1`) | Task-context flush, `-O2` for the trace code, function tracing. |

## 2. Paste `esp_trace_get_user_params()` into the main source file

Paste the contents of `templates/sysview_user_params.c` into the file that has `app_main` (anywhere at file scope). It is guarded by `#if CONFIG_ESP_TRACE_LIB_EXTERNAL`, so the normal build compiles exactly as before. No `CMakeLists.txt` change: `esp_sysview` is a dependency of `main` and publicly requires `esp_trace`, which requires `app_trace`, so the headers are visible.

Why it is needed: IDF's default `esp_trace_get_user_params()` asks for `CONFIG_ESP_TRACE_LIB_NAME`, which is `"ext"` for an external library and has no menuconfig prompt, while `esp_sysview` registers itself as `"sysview"`. Without the override the trace firmware **aborts at boot**: `E esp_trace_core: Encoder 'ext' or transport 'apptrace' not found` then `init function ... has failed (0x105), aborting`. Espressif's `sysview_tracing` example contains the same function. (Still true on v6.1.)

Why in the main file and not a file of its own: the default is a *weak* function inside `libesp_trace.a`, so nothing is undefined and the linker would never pull a separate object out of `libmain.a`. The main file is always linked because it defines `app_main`. Check in the map file: `esp_trace_get_user_params ... libmain.a(<your main file>.obj)`.

## 3. The sdkconfig fragment

Copy `templates/sdkconfig.sysview_jtag` to the project root and **set `CONFIG_IDF_TARGET`** to the chip. Nothing else to edit. It holds the same options as the example's `sdkconfig.defaults` plus `sdkconfig.ci.sysview_jtag`:

- `ESP_TRACE_ENABLE` + `ESP_TRACE_LIB_EXTERNAL` + `ESP_TRACE_TRANSPORT_APPTRACE` + `APPTRACE_DEST_JTAG`: tracing on, SystemView library from the component, data to OpenOCD over JTAG.
- `ESP_TRACE_TS_SOURCE_ESP_TIMER`: 1 µs timestamps from the same clock as `esp_timer_get_time()`.
- `SEGGER_SYSVIEW_EVT_*`: task start/stop/ready, ISR enter/exit, idle, timers.
- `CONFIG_IDF_TARGET`: the trace build folder starts without an `sdkconfig` and would otherwise default to plain `esp32`.

These `SEGGER_SYSVIEW_*` options belong to the component, so they only exist after it is downloaded. The first build prints `unknown kconfig symbol 'SEGGER_SYSVIEW_EVT_...'` while it downloads the component. Usually it then re-configures and finishes by itself; if it stops with *"Re-run the build process"* (exit code 255), run the same command again.

## 4. Build in its own folder

The trace folder needs three `idf.py` options on **every** call (`build`, `flash`, `openocd`, `menuconfig`, ...). `idf.py` reads options from a file given as `@file`, so copy `templates/sysview_jtag.args` to the project root:

```
-B build_trace
-D SDKCONFIG=build_trace/sdkconfig
-D SDKCONFIG_DEFAULTS=sdkconfig.sysview_jtag
```

```powershell
idf.py @sysview_jtag.args build
idf.py @sysview_jtag.args -p COM5 flash
```

- Project with its own `sdkconfig.defaults` (or other defaults files): make the last line `-D SDKCONFIG_DEFAULTS=sdkconfig.defaults;sdkconfig.sysview_jtag` (project files first, the trace fragment last). The file is split like a shell command line; no `#` comments.
- Why all three: with `-B build_trace` alone, `idf.py` silently uses the root `sdkconfig` and builds the normal firmware. `idf.py` prints `Running: idf.py -B build_trace ...` when it expands the file, which is the check.
- Changing the fragment later: delete `build_trace/sdkconfig` first. Defaults are only applied to options not yet in that file.
- Add `build_trace/` and `*.SVDat` to `.gitignore`.
- Several build folders in one project: keep one component-manager lock per folder, or the builds rewrite each other's `dependencies.lock`. In the root `CMakeLists.txt`, between `include(.../project.cmake)` and `project(...)`:

  ```cmake
  idf_build_set_property(DEPENDENCIES_LOCK "${CMAKE_BINARY_DIR}/dependencies.lock")
  ```

Verify before flashing: `CONFIG_ESP_TRACE_LIB_EXTERNAL=y` and `CONFIG_APPTRACE_DEST_JTAG=y` are in `build_trace/sdkconfig`, and the map file shows `SEGGER_SYSVIEW_Start` and `esp_trace_get_user_params` in the main object.

## 5. SystemView on the PC (once)

ESP-IDF numbers the FreeRTOS events its own way. Replace SystemView's FreeRTOS description file with IDF's, keeping a backup (the guide's "Data Visualization" note). Administrator PowerShell:

```powershell
$d = "C:\Program Files\SEGGER\SystemView\Description"
Copy-Item "$d\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt.segger-original"
Copy-Item "$env:IDF_PATH\tools\esp_app_trace\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt" -Force
```

`Program Files` needs elevation. If the agent can't elevate, give the user this block to run.

## 6. Record

Two terminals with the IDF environment, both in the project root. Copy `templates/gdbinit` to the project root first (it records into `build_trace/trace.SVDat`, path relative to where OpenOCD runs).

Terminal 1, OpenOCD (uses the board config from the project's settings; or run `openocd -f board/esp32s3-builtin.cfg` yourself):

```powershell
idf.py @sysview_jtag.args openocd
```

Terminal 2, GDB with the script. It resets the chip, breaks at `app_main`, starts `esp sysview_mcore` and continues, so the trace also contains the task-create events:

```powershell
xtensa-esp32s3-elf-gdb -x gdbinit build_trace\<project>.elf     # riscv32-esp-elf-gdb on C3/C6/H2/P4
```

After the time you want to see (5 to 30 s is plenty for a lesson), in GDB: `Ctrl+C`, then `mon esp sysview_mcore stop`, then `quit`. Stop OpenOCD with `Ctrl+C`. Then in SystemView: **File → Load Data** (`Ctrl+O`) → `build_trace\trace.SVDat`. SystemView ignores a file given on its command line and opens an empty *New Recording*.

Variations the guide allows: `esp sysview_mcore start file://... 0 -1 -1` records until stopped in blocking mode; `esp sysview_mcore start file://trace.SVDat 1 1000000` stops by itself after 1 MB; the commands can also be typed into OpenOCD's telnet port 4444 on a running system (the task list is sent at start, so no reset is required).

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
- **Both cores** appear in one view (SystemView 3.60+ multi-core format). On a dual-core chip look at which core each task ran on; `FROM_CPU_INTR0` around task switches is the cross-core / yield interrupt FreeRTOS uses; it's normal.
- **Durations include tracing overhead.** Each event is encoded and written into the trace buffer; a GPIO-toggle task shows tens of µs where the real work is a few µs. Intervals and counts are exact.
- **Log lines** can be put into the trace too, the way the `sysview_tracing_heap_log` example does: `esp_log_set_vprintf(esp_sysview_vprintf)` at the start of `app_main`, guarded by `#if CONFIG_ESP_TRACE_LIB_EXTERNAL` (header `esp_sysview_heap_trace_module.h` from the component). They show in the *Terminal* window and as markers; lines are cut at 128 characters.

## 8. Clean up and hand back

- Flash the normal firmware again (`idf.py -p COM5 flash`) if the trace build is still on the board.
- Keep in the repo: `sdkconfig.sysview_jtag`, `sysview_jtag.args`, `gdbinit`, the pasted function, `idf_component.yml`, plus a README section with the commands. Never commit `build_trace/`, `.SVDat` files or `managed_components/`.

More symptoms and fixes: `reference/troubleshooting.md`. A checklist for people (same steps, copy-paste commands): `README.md`.
