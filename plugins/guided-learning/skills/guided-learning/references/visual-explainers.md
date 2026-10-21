# Visual explainer patterns

Patterns for the per-task explainer page. Pick the one or two that fit the task's core mechanism; a page with one good simulator beats a page with five decorations.

## Page structure that worked

1. **Header:** task id + a one-line question the page answers ("What happens to your ISR while flash is being written?").
2. **Model:** a diagram of the parts involved (SVG), with the key part highlighted. Elements in the diagram react to the simulator (a link turns red, a block moves).
3. **Try it:** the simulator, with controls above it, the visualization in the middle, live counters below, and a status line that explains in one sentence what is happening right now.
4. **All cases:** a small table of every combination of the settings and what each one does. Highlight the user's own configuration.
5. **Fine print:** 2–4 rules that follow from the mechanism, including a hint that points ahead to the next task.
6. **Your turn:** the control question plus 2–3 guiding questions, no answer.

## Simulator patterns

| Topic | Visualization | Controls |
|---|---|---|
| Timer ISR, interrupts | analyzer traces: alarm ticks, ISR pulse, debug pin | period, ISR duration, "block interrupts" button |
| Flash / cache / IRAM | chip diagram + traces, crash overlay | code location, cache-safe option, "write flash" button |
| Display multiplexing | two digits + per-digit on-time trace, ghosting shown as faint segments | refresh rate slider (20 Hz … 1 kHz), "skip digits-off step" toggle |
| Button debouncing | raw bouncy signal vs debounced output, event markers | bounce length, sample period, stability count |
| State machine | state diagram with the active state lit, event log | event buttons (+, −, START, TICK), reset |
| Shared buffer / race | ISR and task timelines, torn read highlighted | atomic vs two-byte write toggle, speed |
| Power / LED driver | circuit with currents and voltages, heat per part | supply voltage, LED Vf, current setting |
| Transistor switch | circuit + I_B/I_C/Vce readouts, saturated vs active region | base resistor, collector load |

Slow time down so events are visible (e.g. 1 ms of chip time = 0.25 s on screen) and say so on the page. Start the page with a pre-run state so the traces are already visible before anyone presses a button.

## Implementation notes

- One self-contained HTML file: inline CSS/JS, a `<canvas>` for traces, inline SVG for diagrams. No library needed for most of these.
- Read colors from CSS tokens at draw time so the canvas follows light and dark themes.
- Keep the simulator logic in a small `step(dt)` state machine, separate from `draw()`. It's easier to get right, and it mirrors the firmware structure the user is learning.
- Give every control a visible label and a pressed state; respect `prefers-reduced-motion` (start paused).
- Syntax-check the script once (`node --check` on the extracted script) before publishing.
- Update the same page (same file path) during the task instead of publishing new ones.
- Without an Artifact tool, the same file works as a local page: no external requests except an optional pinned CDN script, so it opens straight from disk.
