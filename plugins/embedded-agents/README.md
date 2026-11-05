# embedded-agents

A team of Claude Code subagents for learning embedded development and building real projects on the bench. The coach (the `guided-learning` skill, in the main session) keeps the conversation and delegates bounded work to specialists, which report back in a fixed format.

| Agent | Does | Model | Writes |
|---|---|---|---|
| `idf-librarian` | ESP-IDF v6.1 source, board pinout, datasheet lookups with file:line or page evidence | sonnet | no |
| `firmware-engineer` | Writes or refactors ESP-IDF C under the project's invariants, builds before returning | opus | source |
| `code-reviewer` | Embedded C review: ISR safety, races, timing math, pins, layering, spec invariants | opus | no |
| `bench-eye` | Photos and videos from the bench camera vs the wiring ground truth, LED timing | opus | no |
| `meter-tech` | Measurement plans on the FNIRSI 2C53T through its MCP server, logs to `docs/measurements.jsonl` | sonnet | log only |
| `build-ops` | `idf.py` build / flash / monitor, condensed errors, decoded panics, serial captures | sonnet | no |
| `lesson-author` | Explainer page per task, worked examples with blanks, task lists, quiz items | opus | docs |
| `examiner` | Recall questions due, task-check, SESSION_LOG, spaced-repetition bank in `docs/recall.md` | haiku | logs |
| `project-architect` | New project: spec, ADRs, pin budget, BOM, T01..Tnn task list | fable | plan files |

## Skills

| Skill | Does |
|---|---|
| [`sysview-trace`](skills/sysview-trace/SKILL.md) | Adds SEGGER SystemView to any ESP-IDF v6 FreeRTOS project in a separate build folder: **live** task timeline over the board's COM port (with a small bridge, since SystemView's UART recorder can't talk to ESP-IDF directly) or a **JTAG** recording of all cores. Ships the sdkconfig fragments, the `esp_sysview` dependency, the boot fix (`trace_params.c`), the bridge and capture scripts, and a [troubleshooting table](skills/sysview-trace/reference/troubleshooting.md) from a real bring-up. Ask "trace my tasks" or run `/sysview-trace`. To do it by hand: the [step-by-step checklist](skills/sysview-trace/README.md). |

## Install

```text
/plugin marketplace add eoffers51/claude-skills
/plugin install embedded-agents@beetroot-esp32
/plugin install guided-learning@beetroot-esp32
```

Then paste [`templates/claude-md-delegation.md`](templates/claude-md-delegation.md) into the project's `CLAUDE.md` (or a parent folder's) so the coach knows when to delegate.

## Requirements

The agents preload these skills by name. They must be installed, either as plugins from this marketplace or as user skills in `~/.claude/skills/`:

| Skill | Used by | Where it lives today |
|---|---|---|
| `esp-idf-source` | librarian, engineer | user skill (`~/.claude/skills/esp-idf-source`) |
| `esp32-s3-devkitc-1` | librarian, engineer, bench-eye, architect | user skill |
| `esp-idf-clean-arch` | engineer, reviewer, architect | user skill |
| `bench-camera` | bench-eye | user skill (needs the phone camera app and `adb`) |
| `guided-learning`, `task-check` | lesson-author, examiner | plugin `guided-learning` |
| `wiring-docs` | lesson-author (on demand) | plugin `wiring-docs` |
| `engineering:code-review`, `engineering:architecture`, `engineering:system-design` | reviewer, architect | the `engineering` plugin from the official marketplace |

A missing skill is skipped with a warning in the debug log, and the agent falls back to its own instructions.

`meter-tech` needs the FNIRSI meter MCP server registered where the project runs. Its `.mcp.json` is project-scoped today; register it for the whole user instead:

```text
claude mcp add --scope user meter -- <path-to>/Fnirsi2C53T/.venv/Scripts/python.exe <path-to>/Fnirsi2C53T/tools/meter_mcp.py
```

## How a task flows

```
coach: Orient  -> examiner (recall questions due)
coach: Brief   -> lesson-author (explainer page), idf-librarian (facts)
you wire       -> bench-eye (photo vs board_pins.h / wiring.svg), meter-tech (Vf, resistors, rails)
you code       -> idf-librarian (API questions), build-ops (build, flash, log)
verify         -> bench-eye (video timing), meter-tech (Verified-result numbers), code-reviewer
close          -> examiner (task-check, SESSION_LOG, recall bank)
coach: control questions, one at a time (never delegated)
```

A new project starts with `project-architect`, then runs the same loop per task.

## Design notes

- Subagents start cold and cannot talk to the user mid-run, so teaching stays in the main session.
- Every agent returns a fixed report block (verdict, evidence, confidence) and little prose. The coach quotes the evidence when it teaches.
- Read-only by default. Only the engineer, the lesson author and the two log writers (meter-tech, examiner) can write project files, and each is told exactly which files. Agents with `memory` keep Write/Edit available (the memory feature needs them) and are told to use them only on their own notes; a `disallowedTools: Write, Edit` line would silently break memory.
- `memory: user` lets the agents keep notes across sessions in `~/.claude/agent-memory/<agent>/`, in your home folder and never inside a repo. Do not switch this to `project` on public repos: the notes are model-written and can contain local paths (photo folders, log files) that carry your Windows user name. If you ever do, add `.claude/agent-memory/` to the repo's `.gitignore` first.
- Plugin agents ignore `hooks`, `mcpServers` and `permissionMode` in their frontmatter; permissions come from the project's settings.
- Models: `fable` only for the architecture step (`project-architect`); `opus` for the coach (main session) and for code, review, vision and teaching material, `sonnet` for procedure-driven tool work, `haiku` for bookkeeping. Change the `model:` line in an agent file to re-tune.

## Evaluate before trusting

Use a finished project with known answers as the test bed: ten API questions for `idf-librarian`, photos of a known-good board for `bench-eye`, `/task-check` on closed tasks for `examiner`, a re-measurement of two logged values for `meter-tech`.
