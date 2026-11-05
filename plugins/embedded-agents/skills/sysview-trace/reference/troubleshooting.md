# SystemView on ESP-IDF v6: symptoms and fixes

Every row was hit and fixed on a real board (ESP-IDF v6.0.2, ESP32-S3, esp_sysview 1.0.2, SystemView V4.10b, Windows).

## Build

| Symptom | Cause | Fix |
|---|---|---|
| `unknown kconfig symbol 'SEGGER_SYSVIEW_EVT_...'`, then *"Missing kconfig option. Re-run the build process"*, exit code 255 | The options belong to `esp_sysview`, which is only downloaded during this first configure | Run the same command again |
| `'esp_trace_encoder_vtable_t' has no member named 'flush'` in `adapter_encoder_sysview.c` | `esp_sysview` 1.1.x needs a newer `esp_trace` than IDF v6.0.x | Pin `espressif/esp_sysview: "~1.0.2"` |
| The trace build is the normal firmware (no `SEGGER_SYSVIEW_*` in the map, wrong app) | `idf.py -B <dir>` without `-D SDKCONFIG=<dir>/sdkconfig` uses the root `sdkconfig` | Repeat both `-D` options on every call, including `flash` |
| A changed fragment has no effect | Defaults only fill options missing from `<dir>/sdkconfig` | Delete `<dir>/sdkconfig`, build again |
| `dependencies.lock` flips between builds, the component is re-downloaded | All build folders share one lock file | `idf_build_set_property(DEPENDENCIES_LOCK "${CMAKE_BINARY_DIR}/dependencies.lock")` in the root CMakeLists, before `project()` |
| `PermissionError [WinError 32]` / *".component_hash or CHECKSUMS.json ... does not exist"* | The component manager tried to replace `managed_components/espressif__esp_sysview` while a shell's working directory was inside it; it is now half-deleted | `cd` to the project root, delete `managed_components/espressif__esp_sysview`, build again |
| `trace_params.c` not in the map, boot still asks for `"ext"` | Weak default in `libesp_trace.a` satisfies the symbol; `-u` doesn't help because of link order | `WHOLE_ARCHIVE` on the component when `CONFIG_ESP_TRACE_LIB_EXTERNAL` (template snippet) |

## Boot

| Symptom | Cause | Fix |
|---|---|---|
| `E esp_trace_core: Encoder 'ext' or transport 'apptrace' not found`, `init function ... has failed (0x105), aborting`, boot loop | IDF's default encoder name `"ext"` ≠ `"sysview"` registered by `esp_sysview` | `templates/trace_params.c` + the CMake snippet |
| OpenOCD log: `Halt cause (abort() was called at PC ...)` right after connecting | Same boot abort, seen from JTAG | Same fix; decode with `xtensa-<chip>-elf-addr2line -pfiaC -e <elf> <PC>` (`do_system_init_fn` = an init function failed) and read the boot log on the UART at 115200 |

## Live (UART)

| Symptom | Cause | Fix |
|---|---|---|
| SystemView *"Error while recording. Recorder stopped."* with the UART recorder | ESP-IDF's UART transport doesn't answer SystemView's hello | `scripts/sysview_bridge.py` + SystemView IP recorder `127.0.0.1:19111` |
| Nothing on the COM port | Normal: the firmware waits for START (`0x01`) from the host | Send it (the bridge or SystemView does) |
| No task names, tasks shown as numbers | SystemView was started on a board that was already streaming, so the task list went out earlier | Reset the board before each recording (the bridge does it) |
| Your tasks show `xQueueGenericSend/Receive` and run ~1 ms | `ESP_LOGx` formatting + log lock, even with no console | `CONFIG_LOG_DEFAULT_LEVEL_NONE=y` in the fragment |
| Some tasks never appear | Dual core: over UART only one CPU is traced | `CONFIG_FREERTOS_UNICORE=y` in the fragment, or pin the tasks to the traced core |
| Run times look large (tick ~0.1 ms, tiny task ~0.2 ms) | The trace events themselves go out at 1 Mbaud | Expected. Counts and intervals are exact; use JTAG for less overhead |

## Record (JTAG)

| Symptom | Cause | Fix |
|---|---|---|
| `libusb_open() failed with LIBUSB_ERROR_NOT_FOUND`, `esp_usb_jtag: could not find or open device!` | Windows bound Microsoft's generic WinUSB to *USB JTAG/serial debug unit* without a device interface GUID | `idf-env.exe driver install --espressif` (admin), then replug or remove the device and scan; the driver provider must read `libwdi` |
| Same error right after flashing only | The flash reset re-enumerates the native USB | Wait ~3 s before starting OpenOCD |
| `sysview: Failed to stop tracing!`, `Size is 0` | Target aborted at boot (see Boot) or wasn't running | Fix the firmware first |
| SystemView opens empty (*New Recording*, 0 events) | SystemView ignores a file passed on the command line | *File → Load Data* (`Ctrl+O`) |

## SystemView display

| Symptom | Cause | Fix |
|---|---|---|
| Dozens of `WIFI_*`, `BT_*`, `UART*` rows with 0 activations | The system description lists every interrupt the chip has | Sort the Context window by Activations, untick rows |
| A task's timeline row is empty | Zoomed to a few ms, shorter than the task's period | Zoom out past the slowest period, or double-click an event of the task |
| Wrong FreeRTOS event names | SystemView's own `SYSVIEW_FreeRTOS.txt` | Replace it with `$IDF_PATH/tools/esp_app_trace/SYSVIEW_FreeRTOS.txt` (admin) |
