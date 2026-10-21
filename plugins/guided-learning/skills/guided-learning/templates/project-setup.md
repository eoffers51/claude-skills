# Project setup for guided learning

The skills work best when the project has three files. Copy what you need and adapt it.

## 1. `CLAUDE.md` (project rules)

```markdown
# CLAUDE.md

<One line: what the project is, which board, which framework.>
- Spec: @TASK.md
- Task list with "Verified result" + control questions per task: @TASKS.md
- Where the last session stopped: @SESSION_LOG.md. Keep it current: update **Current state**
  and add a short dated History entry when a task step finishes, a decision is made, or the user wraps up.
  `docs/log.md` belongs to the user, so don't write to it.

## How to help: guide, don't solve
- Run each task with the `guided-learning` skill.
- Default to explaining, reviewing, and giving hints. Write or change code only when the user explicitly asks for it.
- Control-question answers come from the user's own words. Measured bench values come from the user, so never invent them.
- Tasks are done in order. Don't jump ahead of the task the user is on.

## Build / test
- <exact build command, e.g. `idf.py build`; how to activate the toolchain; serial port>
- <how to run tests, if any>

## Hard constraints
- <rules that must never be broken, e.g. "pin numbers live only in board_pins.h">
```

## 2. `TASKS.md` (task list)

Each task needs a **Verified result** (how you know it is done) and **Control questions** (what you should be able to explain). `task-check` reads exactly these headings.

```markdown
| # | Task | Done |
|---|---|---|
| T01 | Project skeleton | ☐ |
| T02 | ... | ☐ |

### T01. Project skeleton
**Goal:** a project that builds, flashes and logs.

Steps:
1. ...

**Verified result**
- `idf.py build flash monitor` shows the log line after reset.
- `docs/log.md` created with the first entry.

**Control questions**
1. What does `app_main` run inside: which task, which core, what stack size?
```

## 3. `SESSION_LOG.md` (handoff file, Claude keeps it)

```markdown
# Session log

## Current state
- Task: T03, step 2 of 4 (resistor measured, current not calculated yet)
- Open questions / misconceptions to revisit: <...>

## History
- 2026-10-14: T02 done, all 16 segments confirmed.
```

`docs/log.md` is **your** lab notebook: dates, measured numbers, photos, control-question answers.
