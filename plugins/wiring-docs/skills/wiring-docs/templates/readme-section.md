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

Wokwi simulates the <CHIP> and runs the compiled firmware. It can't compile ESP-IDF in the browser, so you give it the `.bin` built by `idf.py` or CI.

- **Browser:** open the [**Wokwi project**](https://wokwi.com/projects/<PROJECT_ID>), download `<PROJECT>-merged.bin` from the [latest release](https://github.com/<USER>/<REPO>/releases/latest) (or, for the newest commit, from the `<ARTIFACT>` artifact of a [CI run](https://github.com/<USER>/<REPO>/actions) — needs a GitHub login, unzip it first), click in the code editor, press **F1 → Upload Firmware and Start Simulation…** and pick the file.
- **VS Code:** install the *Wokwi Simulator* extension, run `idf.py build`, then *Wokwi: Start Simulator* ([`wokwi.toml`](wokwi.toml) points it at the build, [`diagram.json`](diagram.json) holds the circuit).

<Board differences, e.g.: Wokwi's DevKitC-1 has its RGB LED on GPIO38 and no clickable Boot button, so the diagram adds a NeoPixel on **GPIO48** and a button on **GPIO0** to match this board.>
<Simulator quirks that affect this project, e.g. LED smoothing hiding flashes shorter than ~100 ms.>
