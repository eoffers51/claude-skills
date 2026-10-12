# Wokwi-only files

The [Wokwi project](https://wokwi.com/projects/<PROJECT_ID>) holds a copy of this repo's code so it runs in the browser. Wokwi compiles ESP-IDF code with the **Arduino ESP32 core**, which needs small changes:

| File in Wokwi | Comes from |
|---|---|
| `sketch.ino` | [`wokwi/sketch.ino`](sketch.ino): `setup()` calls our `app_main`, renamed to `<project>_app_main` (the Arduino core already has an `app_main`) |
| `main.c` | `main/main.c` with `#define app_main <project>_app_main` added at the top |
| `<module>.c` | [`wokwi/<module>.c`](.): same header API, without the registry component the core doesn't have |
| other `.c` / `.h` | copied unchanged from `components/` (flat names) |
| `diagram.json` | [`diagram.json`](../diagram.json) |

When the code changes, upload the changed files to the Wokwi project again (file menu ▾ → *Upload file(s)…*) and press **Save**.
