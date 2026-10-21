# 🧰 Claude Code skills for ESP32 projects

Reusable [Claude Code](https://claude.com/claude-code) skills from Beetroot Academy embedded lessons. Install once, then use them in any of your projects.

| Plugin | What it does |
|---|---|
| [`wiring-docs`](plugins/wiring-docs/skills/wiring-docs/SKILL.md) | Reads the pins from your code and makes **a wiring picture for the README** (`docs/wiring.svg`) and **a Wokwi simulator project** (`diagram.json`, `wokwi.toml`). It puts your code in a wokwi.com project that runs when anyone presses ▶, tests every mode and adds a "Simulate" badge to the README. |
| [`guided-learning`](plugins/guided-learning/skills/guided-learning/SKILL.md) | A **learning coach** for course task lists (T01, T02, …). It explains each task with an interactive visual page, gives hints step by step instead of ready answers, coaches debugging, and asks the control questions one at a time. It also adds **`/task-check T07`**, which checks a task against its "Verified result" and lists what is still open. |

Example result: [Lesson 1.3 — Police siren](https://github.com/eoffers51/Lesson_1_3_Blink#-wiring) · [its Wokwi project](https://wokwi.com/projects/477675527233048577)

![Example wiring picture](plugins/wiring-docs/skills/wiring-docs/templates/wiring-example.svg)

## 📦 Install

In Claude Code (any project):

```text
/plugin marketplace add eoffers51/claude-skills
/plugin install wiring-docs@beetroot-esp32
/plugin install guided-learning@beetroot-esp32
```

Update later with `/plugin marketplace update beetroot-esp32`.

<details>
<summary>Without the plugin system (copy the folder)</summary>

```bash
git clone https://github.com/eoffers51/claude-skills
# for all your projects (same for guided-learning/skills/guided-learning and guided-learning/skills/task-check):
cp -r claude-skills/plugins/wiring-docs/skills/wiring-docs ~/.claude/skills/
# or only for one project:
cp -r claude-skills/plugins/wiring-docs/skills/wiring-docs <your-project>/.claude/skills/
```

</details>

## ▶️ Use

Open your project in Claude Code and ask, for example:

> Add an accurate wiring diagram to the README and a Wokwi simulator link for this project

or call it directly: `/wiring-docs`.

Claude will:
1. read the pins from your code and ask about the things the code can't show (resistor values, LED polarity, which parts are on the board);
2. show you a wiring table to confirm;
3. draw `docs/wiring.svg` and make `diagram.json` + `wokwi.toml`;
4. (if you have [Claude in Chrome](https://claude.com/chrome) and are signed in to [wokwi.com](https://wokwi.com)) build the circuit on wokwi.com, upload your source code (plus tiny Wokwi-only files in `wokwi/` for ESP-IDF projects), press ▶, test every mode, and **ask you** before saving it (free plan = public project);
5. update the README.

### Requirements (wiring-docs)

- Claude Code
- Git Bash on Windows (or any bash on macOS/Linux), `curl`, Python 3, and Chrome or Edge (used to check the SVG picture)
- For the online simulator: a free [wokwi.com](https://wokwi.com) account and the Claude in Chrome extension
- ESP-IDF projects: nothing extra for wokwi.com (it compiles your code); `idf.py build` only for the VS Code simulator

## 🎓 Learning with `guided-learning`

The skill coaches you; it doesn't do the task for you. It works from three files in your project (copy-paste setup in [`project-setup.md`](plugins/guided-learning/skills/guided-learning/templates/project-setup.md)):

- `CLAUDE.md`: the rules ("guide, don't solve", build commands, hard constraints);
- `TASKS.md`: tasks, each with a **Verified result** and **Control questions**;
- `SESSION_LOG.md`: where the last session stopped (Claude keeps it up to date).

Then just say:

> lets start next task

For each task, Claude will:
1. ask one quick question about the previous task, then explain the goal, why it matters, and what "done" looks like;
2. make an interactive page for the main idea (diagram, timing traces, a small simulator you can play with);
3. split the task into small steps, each with "what you should see";
4. when you're stuck, give hints one level at a time: a question → where to look → a partial example → the full code only if you ask for it (with every line explained);
5. check the result (`/task-check T05`): ✅ / ❌ / ⏳ per item;
6. ask the control questions one at a time and build the final answer from **your** words;
7. finish with a short summary and update `SESSION_LOG.md`.

Works without the Artifact tool too: the visual pages are then saved as local HTML files you open in the browser.

## 🗂️ Layout

```text
.claude-plugin/marketplace.json        marketplace "beetroot-esp32"
plugins/<plugin>/.claude-plugin/plugin.json
plugins/<plugin>/skills/<skill>/SKILL.md   the instructions Claude follows
                         reference/        details loaded only when needed
                         templates/        example files to start from
                         scripts/          helper scripts
```

To add a skill: create `plugins/<name>/` the same way, add it to `marketplace.json`, bump the versions, and check with `claude plugin validate .`.

## License

MIT
