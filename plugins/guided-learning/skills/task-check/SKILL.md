---
name: task-check
description: Check a learning-project task (T01, T07, S2, ...) against its "Verified result" criteria in the project's task list and report what is done vs. still open, with one hint per missing control question. Use when the user asks "is T07 done?", "check my task", "what's left for this task", or runs /task-check T<nn>.
argument-hint: T<nn>
---

Check task `$ARGUMENTS`. If no task is given, take the current one from the handoff file (e.g. `SESSION_LOG.md`) or the first unticked row of the task list, and say which one you picked.

0. Find the files. Read `CLAUDE.md` first: it names the task list (usually `TASKS*.md`), the log file (usually `docs/log.md`), and the build and test commands. If it doesn't, look for a `TASKS*.md` file in the project root and ask the user if there is more than one.
1. Read that task's section: Goal, Steps, **Verified result**, Control questions.
2. For each Verified-result item, decide which kind it is:
   - **Checkable by Claude:** grep/file checks, builds, host tests. Run these checks and report the actual output.
     - Use the exact build and test commands from `CLAUDE.md` (e.g. activating ESP-IDF before `idf.py build`).
     - ESP-IDF: if there is no `sdkconfig` in the project root (fresh clone), run `idf.py set-target <chip>` first. Never run `set-target` when `sdkconfig` exists, because it regenerates the config.
     - If a check needs an environment you can't reach (a devcontainer, a Linux-only toolchain), tell the user to run it there instead of improvising on another platform.
   - **Bench / measurement:** flashing, scope or logic-analyzer readings, multimeter values, visual checks. Don't run or guess these. Check whether the log file has a dated entry with the numbers.
3. Check the task's **Steps** too. For each step, look for evidence in the code or in `docs/` that it was done (e.g. a removed test loop, a config option, a file that should exist). Report only the steps that are missing or contradicted. Don't list steps that are fine.
4. Check that the log file has an answer to each control question for this task. Only report whether each answer is present. Don't judge it, rewrite it, or suggest answers.
   - For each **missing** answer, give exactly **one** leading hint: a spec section, a datasheet value, or a question that points the user in the right direction. The hint must not contain the answer itself.
5. End with this fixed summary format and nothing after it:

   ```
   ## T<nn> status
   ✅ <item> — <evidence: command output, file:line, log entry date>
   ❌ <item> — <what failed, actual output>
   ⏳ <item> — <waiting on: bench measurement / log entry / control question>

   **Steps:** all done | missing: <list>
   **Control questions:** <n>/<total> answered
   **Verdict:** DONE | NOT DONE

   ### Next 3 actions
   1. ...
   2. ...
   3. ...
   ```

   The verdict is DONE only if there are no ❌ and no ⏳ items. Order the next actions by what unblocks the most. If the task is DONE, the actions are: tick it in the overview table, commit, start the next task.

Don't fix anything. If something fails, explain why and give a hint (spec section, API to look at). Write the fix only if the user asks for it.
