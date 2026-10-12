<!-- Badge: put next to the other badges at the top of README.md -->
[![Simulate on Wokwi](https://img.shields.io/badge/simulate-Wokwi-6c4cbb)](https://wokwi.com/projects/<PROJECT_ID>)

<!-- Under the wiring heading -->
## 🔌 Wiring

![Wiring diagram](docs/wiring.svg)

<details>
<summary>Text version</summary>

```text
<old ASCII diagram, if any>
```

</details>

<!-- New section -->
## 🖥️ Simulate in Wokwi

**[▶ Open the Wokwi project](https://wokwi.com/projects/<PROJECT_ID>)** and press the green ▶ button (the first build can take a minute or two on Wokwi's free servers). <How to interact, e.g. click BOOT to switch modes.>

The Wokwi project runs this repo's own C code. Wokwi compiles ESP-IDF code with the Arduino ESP32 core, so [`wokwi/`](wokwi) has a few small Wokwi-only files <list them>. The `ESP_LOGI` messages don't appear in Wokwi's serial monitor.

- **VS Code:** install the *Wokwi Simulator* extension, run `idf.py build`, then *Wokwi: Start Simulator* — this runs the real firmware ([`wokwi.toml`](wokwi.toml) points to the build, [`diagram.json`](diagram.json) holds the circuit).

<Board differences, e.g.: Wokwi's DevKitC-1 has its RGB LED on GPIO38 and no clickable Boot button, so the diagram adds a NeoPixel on **GPIO48** and a button on **GPIO0** to match this board.>
<Simulator quirks that affect this project, e.g. LED smoothing hiding flashes shorter than ~100 ms.>
