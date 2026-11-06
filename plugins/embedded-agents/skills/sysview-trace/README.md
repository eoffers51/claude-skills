# Record a SEGGER SystemView trace of an ESP-IDF project

A checklist for people. It records which FreeRTOS task runs when, how often, and how much CPU it uses, and shows it in SystemView. Only Espressif's and SEGGER's own tools are used, the way their documentation shows. It takes about 10 minutes, and your normal build stays exactly as it is.

**You need:**
- ESP-IDF **v6.x** (for v5.x see IDF's `examples/system/sysview_tracing`).
- A JTAG link: on ESP32-S3/C3/C5/C6/H2/P4 the board's **native USB** port (built-in USB-JTAG); on ESP32/S2 an ESP-Prog or similar probe. Plus the usual USB-UART port for flashing.
- [SEGGER SystemView](https://www.segger.com/products/development-tools/systemview/) **3.60 or newer** installed (free for non-commercial use).

In the commands, `$S` is this folder (`skills/sysview-trace`), `COM5` is your board's USB-UART port and `esp32s3` your chip. Run them from your **project root**, in a PowerShell with the ESP-IDF environment active.

```powershell
$S = "<path to>\claude-skills\plugins\embedded-agents\skills\sysview-trace"
```

## 1. Copy four files

```powershell
Copy-Item $S\templates\sdkconfig.sysview_jtag .
Copy-Item $S\templates\sysview_jtag.args .
Copy-Item $S\templates\gdbinit .
Copy-Item $S\templates\idf_component.yml main\   # if main\idf_component.yml exists, merge the esp_sysview entry instead
```

ESP-IDF **v6.1 or newer**? In `main\idf_component.yml` change the `esp_sysview` version from `"~1.0.2"` to `"^1.1"` (1.1.x does not compile on v6.0.x).

## 2. Set your chip

Open `sdkconfig.sysview_jtag` and set `CONFIG_IDF_TARGET` to your chip (`"esp32s3"`, `"esp32c3"`, …). The template has `esp32s3`.

## 3. Paste one function into your main file

Open `$S\templates\sysview_user_params.c` and paste its contents into the source file that has `app_main` (for example at the end of `main.c`). It tells ESP-IDF to use the SystemView encoder and is the same function as in ESP-IDF's `sysview_tracing` example. It is wrapped in `#if CONFIG_ESP_TRACE_LIB_EXTERNAL`, so your normal build does not change. No `CMakeLists.txt` edits.

## 4. Build and flash the trace firmware

The trace firmware goes into its own folder `build_trace/`. `build/` and your `sdkconfig` are not touched. The three `idf.py` options it needs are in `sysview_jtag.args`, and `idf.py` reads them from there:

```powershell
idf.py '@sysview_jtag.args' build
idf.py '@sysview_jtag.args' -p COM5 flash
```

- Keep the quotes around `'@sysview_jtag.args'`: in PowerShell a bare `@name` is splatting and the line fails with *"The splatting operator '@' cannot be used ..."* before `idf.py` starts.
- `idf.py` prints `Running: idf.py -B build_trace -D SDKCONFIG=... build` first. If you don't see that line, the `@` file was not picked up and you just built your normal firmware.
- The first build downloads `esp_sysview` and prints `unknown kconfig symbol 'SEGGER_SYSVIEW_...'` notes. That's normal. If it stops with *"Re-run the build process"*, run the same `build` command again.
- If your project has a `sdkconfig.defaults`, edit the last line of `sysview_jtag.args` to `-D SDKCONFIG_DEFAULTS=sdkconfig.defaults;sdkconfig.sysview_jtag`.
- After you change `sdkconfig.sysview_jtag`, delete `build_trace\sdkconfig` before building again.
- Add `build_trace/` and `*.SVDat` to `.gitignore`.

## 5. Prepare SystemView (once per PC)

ESP-IDF numbers the FreeRTOS events differently from SEGGER. In an **administrator** PowerShell (the original file is kept as a backup):

```powershell
$d = "C:\Program Files\SEGGER\SystemView\Description"
Copy-Item "$d\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt.segger-original"
Copy-Item "$env:IDF_PATH\tools\esp_app_trace\SYSVIEW_FreeRTOS.txt" "$d\SYSVIEW_FreeRTOS.txt" -Force
```

## 6. Record

Connect both USB cables. Two PowerShell windows with the ESP-IDF environment, both in the project root.

Window 1, OpenOCD:

```powershell
idf.py '@sysview_jtag.args' openocd
```

Window 2, GDB with the prepared script. It restarts the chip through OpenOCD, waits 3 seconds for the program to boot, starts the recording into `build_trace\trace.SVDat` and leaves the program running:

```powershell
xtensa-esp32s3-elf-gdb -x gdbinit build_trace\<your_project>.elf     # riscv32-esp-elf-gdb on C3/C6/H2/P4
```

Let it run for as long as you want to see (5 to 30 seconds), then at the `(gdb)` prompt type:

```
mon esp sysview_mcore stop
quit
```

(answer `y`). Stop OpenOCD with `Ctrl+C`. The restart matters: a trace over JTAG only works when the program booted while OpenOCD was connected. If you reset the board by hand or reflash, run the GDB script again.

Windows, first time with the built-in USB-JTAG: if OpenOCD says `libusb_open() failed with LIBUSB_ERROR_NOT_FOUND`, install Espressif's driver (administrator PowerShell), then unplug and replug the native USB cable:

```powershell
Invoke-WebRequest 'https://dl.espressif.com/dl/idf-env/idf-env.exe' -OutFile .\idf-env.exe; .\idf-env.exe driver install --espressif
```

## 7. Look at it

SystemView: **File → Load Data** (`Ctrl+O`) → `build_trace\trace.SVDat`. (SystemView ignores a file given on its command line.)

- **Context** window: click **Activations** to sort. Your tasks, `Idle` and the tick come first. The many rows with 0 activations are just every interrupt the chip has; untick them.
- **The tick** is `SYSTIMER_TARGET0` (the hardware timer) with `SysTick` (FreeRTOS's handler) inside it, `CONFIG_FREERTOS_HZ` times a second.
- **A periodic task** should have about *recording time ÷ period* activations.
- **Timeline**: zoom out past your slowest task's period, or its row looks empty.
- **Run times include a little tracing overhead.** Counts and intervals are exact.

## 8. Back to normal

```powershell
idf.py -p COM5 flash
```

## Why no live view?

Espressif's guide mentions real-time viewing over UART, but SystemView's UART recorder needs a handshake that the `esp_sysview` component does not send, so it stops with *"Error while recording"*. Making it work needs extra software that is not part of ESP-IDF or SystemView, so this checklist records over JTAG instead: same information, all cores, a few seconds later.

Problems: [`reference/troubleshooting.md`](reference/troubleshooting.md).
