# Add SEGGER SystemView to an ESP-IDF project

A checklist for people. It shows your FreeRTOS tasks **live** in SystemView: which task runs when, how often, and how much CPU it uses. It takes about 10 minutes, and your normal build stays exactly as it is.

**You need:**
- ESP-IDF **v6.x** (for v5.x see IDF's `examples/system/sysview_tracing`).
- A board with a **USB-UART chip** (CP210x, CH34x, …), the "COM" port.
- [SEGGER SystemView](https://www.segger.com/products/development-tools/systemview/) installed (free for non-commercial use).

In the commands, `$S` is this folder (`skills/sysview-trace`) and `COM5` is your board's port. Run them from your **project root**, in a PowerShell with the ESP-IDF environment active.

```powershell
$S = "<path to>\claude-skills\plugins\embedded-agents\skills\sysview-trace"
```

## 1. Copy four files

```powershell
Copy-Item $S\templates\sdkconfig.sysview_uart .
Copy-Item $S\templates\trace_params.c main\
New-Item -ItemType Directory -Force tools | Out-Null
Copy-Item $S\scripts\sysview_bridge.py tools\
Copy-Item $S\templates\idf_component.yml main\   # if main\idf_component.yml exists, merge the esp_sysview entry instead
```

## 2. Set your chip and its UART pins

Open `sdkconfig.sysview_uart` and set:
- `CONFIG_IDF_TARGET` to your chip (`"esp32s3"`, `"esp32c3"`, …).
- `CONFIG_APPTRACE_UART_TX_GPIO` / `RX_GPIO` to that chip's **UART0** pins.

The template has the ESP32-S3 values.

| Chip | TX | RX |
|---|---|---|
| ESP32 | 1 | 3 |
| ESP32-S2 / S3 | 43 | 44 |
| ESP32-C3 | 21 | 20 |
| ESP32-C6 | 16 | 17 |
| ESP32-H2 | 24 | 23 |
| ESP32-P4 | 37 | 38 |

## 3. Edit `main/CMakeLists.txt`

Put the sources and requirements in variables and add the `if` block. For a new project, the whole file looks like this (use your own source names and requirements):

```cmake
set(srcs "main.c")
set(priv_requires "")
set(extra_args "")

# SystemView trace build only: tell esp_trace which encoder to open (trace_params.c).
# WHOLE_ARCHIVE is needed, or the linker skips trace_params.c (IDF has a weak default).
if(CONFIG_ESP_TRACE_LIB_EXTERNAL)
    list(APPEND srcs "trace_params.c")
    list(APPEND priv_requires esp_trace)
    list(APPEND extra_args WHOLE_ARCHIVE)
endif()

idf_component_register(SRCS ${srcs}
                       PRIV_REQUIRES ${priv_requires}
                       ${extra_args})
```

Optional, only if you use **more than one build folder**: in the root `CMakeLists.txt`, add this line between `include(...project.cmake)` and `project(...)` so each folder keeps its own `dependencies.lock`:

```cmake
idf_build_set_property(DEPENDENCIES_LOCK "${CMAKE_BINARY_DIR}/dependencies.lock")
```

Add `build_live/` to `.gitignore`.

## 4. Build and flash the trace firmware

The trace firmware goes into its own folder `build_live/`. `build/` and your `sdkconfig` are not touched.

```powershell
$T = @("-B", "build_live", "-D", "SDKCONFIG=build_live/sdkconfig", "-D", "SDKCONFIG_DEFAULTS=sdkconfig.sysview_uart")
idf.py @T build
idf.py @T -p COM5 flash
```

- The first build downloads `esp_sysview` and prints `unknown kconfig symbol 'SEGGER_SYSVIEW_...'` notes. That's normal. If it stops with *"Re-run the build process"*, run the same `build` command again.
- If your project has a `sdkconfig.defaults`, list it first: `"SDKCONFIG_DEFAULTS=sdkconfig.defaults;sdkconfig.sysview_uart"`.
- Always pass all of `$T`. `idf.py -B build_live` **without** the `-D` options silently builds your normal firmware.
- After you change `sdkconfig.sysview_uart`, delete `build_live\sdkconfig` before building again.

## 5. Prepare SystemView (once per PC)

ESP-IDF numbers the FreeRTOS events differently from SEGGER. In an **administrator** PowerShell (the original file is kept as a backup):

```powershell
$d = "C:\Program Files\SEGGER\SystemView\Description"
Copy-Item "$d\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt.segger-original"
Copy-Item "$env:IDF_PATH\tools\esp_app_trace\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt" -Force
```

## 6. Watch it live

```powershell
python tools/sysview_bridge.py --port COM5
```

In SystemView:
1. **Target → Recorder Configuration** → **IP**, address `127.0.0.1`, port `19111`.
2. **Target → Start Recording** (`F5`).

The bridge holds COM5 until you press `Ctrl+C`, so stop it before you flash.

## 7. Read the result

- **Context** window: click **Activations** to sort. Your tasks, `Idle` and the tick come first. The many rows with 0 activations are just every interrupt the chip has; untick them.
- **The tick** is `SYSTIMER_TARGET0` (the hardware timer) with `SysTick` (FreeRTOS's handler) inside it, `CONFIG_FREERTOS_HZ` times a second.
- **A periodic task** should have about *recording time ÷ period* activations.
- **Timeline**: zoom out past your slowest task's period, or its row looks empty.
- **Run times include tracing overhead.** Each event goes out at 1 Mbaud, so a tiny task shows about 0.2 ms. Counts and intervals are exact.

## 8. Back to normal

```powershell
idf.py -p COM5 flash
```

## What changes in the trace build

| Setting | Why |
|---|---|
| Trace on UART0, 1 Mbaud | The trace uses the same USB cable as flashing |
| Console and logging off | COM5 now carries the trace. Logging is also turned off because formatting log lines would still cost ~1 ms per line in your tasks |
| FreeRTOS on core 0 only | Over UART SystemView sees one core; this way no task is missing |
| `trace_params.c` | IDF asks for a trace encoder called `"ext"`, esp_sysview registers `"sysview"`; without it the firmware aborts at boot |
| `esp_sysview ~1.0.2` | 1.1.x doesn't compile with ESP-IDF v6.0.x |
| The bridge | SystemView's own UART recorder fails with *"Error while recording"*; the bridge does its handshake and connects SystemView's IP recorder to COM5 |

Problems: [`reference/troubleshooting.md`](reference/troubleshooting.md). Recording both cores over JTAG instead: [`SKILL.md`](SKILL.md), step 6b.
