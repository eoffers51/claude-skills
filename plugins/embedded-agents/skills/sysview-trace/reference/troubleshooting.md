# SystemView on ESP-IDF v6: symptoms and fixes

Rows without a mark were hit and fixed on a real board (ESP-IDF v6.0.2, ESP32-S3, esp_sysview 1.0.2, SystemView V4.10b, Windows). Rows marked † come from reading the ESP-IDF v6.0.2 / v6.1 and esp_sysview 1.0.2 / 1.1.2 sources.

## Build

| Symptom | Cause | Fix |
|---|---|---|
| `unknown kconfig symbol 'SEGGER_SYSVIEW_EVT_...'`, then *"Missing kconfig option. Re-run the build process"*, exit code 255 | The options belong to `esp_sysview`, which is only downloaded during this first configure | Run the same command again |
| `'esp_trace_encoder_vtable_t' has no member named 'flush'` in `adapter_encoder_sysview.c` | `esp_sysview` 1.1.x needs the `flush` hook that `esp_trace` only has from IDF v6.1 | On IDF v6.0.x pin `espressif/esp_sysview: "~1.0.2"`; on v6.1+ `"^1.1"` is fine |
| The trace build is the normal firmware (no `SEGGER_SYSVIEW_*` in the map, wrong app) | `idf.py -B <dir>` without `-D SDKCONFIG=<dir>/sdkconfig` uses the root `sdkconfig` | Use `idf.py @sysview_jtag.args ...` on every call; `idf.py` must print `Running: idf.py -B build_trace -D SDKCONFIG=...` |
| A changed fragment has no effect | Defaults only fill options missing from `<dir>/sdkconfig` | Delete `<dir>/sdkconfig`, build again |
| `dependencies.lock` flips between builds, the component is re-downloaded | All build folders share one lock file | `idf_build_set_property(DEPENDENCIES_LOCK "${CMAKE_BINARY_DIR}/dependencies.lock")` in the root CMakeLists, before `project()` |
| `PermissionError [WinError 32]` / *".component_hash or CHECKSUMS.json ... does not exist"* | The component manager tried to replace `managed_components/espressif__esp_sysview` while a shell's working directory was inside it; it is now half-deleted | `cd` to the project root, delete `managed_components/espressif__esp_sysview`, build again |
| `esp_trace_get_user_params` from your code is not in the map, boot still asks for `"ext"` | The function was put in a file of its own; the weak default in `libesp_trace.a` already satisfies the symbol, so the linker never pulls that object in | Paste it into the main source file (the one with `app_main`), as the example does |
| † `esp_trace.h` / `esp_app_trace.h: No such file or directory` | The `esp_sysview` dependency is missing from `main/idf_component.yml`, or the build is not the trace build (`CONFIG_ESP_TRACE_LIB_EXTERNAL` off and the `#if` guard was removed) | Keep the `#if CONFIG_ESP_TRACE_LIB_EXTERNAL` guard; check the manifest and `build_trace/sdkconfig` |
| † `'C:\...\python.exe' is currently active in the environment while the project was configured with '...'. Run 'idf.py fullclean'` | Two ESP-IDF Python environments on the PC (installer vs. `export.ps1`) | Activate the environment the build folder was created with, or `idf.py @sysview_jtag.args fullclean` |

## Boot

| Symptom | Cause | Fix |
|---|---|---|
| `E esp_trace_core: Encoder 'ext' or transport 'apptrace' not found`, `init function ... has failed (0x105), aborting`, boot loop | IDF's default encoder name `"ext"` (`CONFIG_ESP_TRACE_LIB_NAME`, no menuconfig prompt) ≠ `"sysview"` registered by `esp_sysview` | Paste `templates/sysview_user_params.c` into the main source file |
| OpenOCD log: `Halt cause (abort() was called at PC ...)` right after connecting | Same boot abort, seen from JTAG | Same fix; decode with `xtensa-<chip>-elf-addr2line -pfiaC -e <elf> <PC>` (`do_system_init_fn` = an init function failed) and read the boot log on the UART |

## Record (JTAG)

| Symptom | Cause | Fix |
|---|---|---|
| `libusb_open() failed with LIBUSB_ERROR_NOT_FOUND`, `esp_usb_jtag: could not find or open device!` | Windows bound Microsoft's generic WinUSB to *USB JTAG/serial debug unit* without a device interface GUID | `idf-env.exe driver install --espressif` (admin), then replug or remove the device and scan; the driver provider must read `libwdi` |
| Same error right after flashing only | The flash reset re-enumerates the native USB | Wait ~3 s before starting OpenOCD |
| `sysview: Failed to stop tracing!`, `Size is 0` | Target aborted at boot (see Boot) or wasn't running | Fix the firmware first |
| The `.SVDat` is empty or missing | `file://` path relative to OpenOCD's working directory does not exist, or OpenOCD was started elsewhere | Start OpenOCD in the project root (`idf.py @sysview_jtag.args openocd`) so `file://build_trace/trace.SVDat` resolves, or use an absolute path in `gdbinit` |
| GDB stops at `app_main` and nothing happens | The `commands ... end` block did not run (gdbinit not loaded) | Start GDB with `-x gdbinit` from the project root; check `set pagination off` is the first line |
| † *Overflow* events in the trace | Bursts of events faster than the JTAG link drains the trace memory | Trace fewer events (`CONFIG_SEGGER_SYSVIEW_EVT_*`), or `CONFIG_SEGGER_SYSVIEW_BUF_WAIT_TMO=-1` to never drop an event (tasks then block) |
| SystemView opens empty (*New Recording*, 0 events) | SystemView ignores a file passed on the command line | *File → Load Data* (`Ctrl+O`) |
| SystemView refuses the file or shows one core only | SystemView older than 3.60 cannot read the multi-core format | Update SystemView, or use `esp sysview start file://pro.SVDat file://app.SVDat` (two files, two SystemView instances) |

## SystemView display

| Symptom | Cause | Fix |
|---|---|---|
| Dozens of `WIFI_*`, `BT_*`, `UART*` rows with 0 activations | The system description lists every interrupt the chip has | Sort the Context window by Activations, untick rows |
| A task's timeline row is empty | Zoomed to a few ms, shorter than the task's period | Zoom out past the slowest period, or double-click an event of the task |
| Wrong FreeRTOS event names | SystemView's own `SYSVIEW_FreeRTOS.txt` | Replace it with `$IDF_PATH/tools/esp_app_trace/SYSVIEW_FreeRTOS.txt` (admin) |
| Your tasks show `xQueueGenericSend/Receive` and run ~1 ms | `ESP_LOGx` formatting and the log lock inside the task | Expected cost of logging; lower the log level in the trace build, or send logs into the trace with `esp_log_set_vprintf(esp_sysview_vprintf)` |

## Live view over UART (not provided by this skill)

| Symptom | Cause | Status |
|---|---|---|
| SystemView UART recorder: *"Error while recording. Recorder stopped."* with an apptrace-UART build | The recorder expects SEGGER's 4-byte target hello; ESP-IDF's transports and `esp_sysview` (≤1.1.2) do not send it | Needs an `esp_sysview` change or a host-side bridge program, both outside ESP-IDF/SystemView. Record over JTAG instead |
