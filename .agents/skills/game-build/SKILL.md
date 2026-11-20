---
name: Game Build
description: Implement or prototype a game feature, mechanic, scene or fix in the Godot project — test-first, smallest reversible change, headless proof before claiming it works. Use whenever the task changes game code, scenes, input, data resources or tests.
---

# Game Build

Implement the smallest change that makes the next playable or observable thing
true. The plan already decided what; this skill protects how.

## First

1. Read `harness/project.md` for engine version, project path, commands,
   conventions and current milestone. Missing profile means ask, not guess.
2. Read the relevant design or plan (`docs/superpowers/specs/`,
   `docs/superpowers/plans/`) and the current code. Do not implement an
   unapproved design.
3. Load the `test-driven-development` skill. It governs every code step.

## Workflow

1. **Find the failing check.** Locate the existing headless check in
   `game/tests/` or write one that expresses the new behaviour. Run it and
   watch it fail for the right reason.
2. **Implement the minimum.** Smallest change that makes the check pass. No
   speculative systems, no new dependency, no autoload or framework without a
   recorded reason and owner agreement.
3. **Re-run the check.** Read the output; do not infer a pass.
4. **Smoke the scene.** Run the headless scene load for the scene you touched.
   If the change is visual or interactive, say that the human playtest is still
   required.
5. **Run the full gate** when the change is done: `tools/verify.ps1` if an
   engine path is available, otherwise the relevant checks by name and state
   what was not run.
6. **Report** the exact commands, their observed results, files changed, and
   anything deferred.

## Conventions

- Godot **4.7.2** only; project at `game/`.
- Files/folders `snake_case`; scene root nodes `PascalCase` matching the file;
  scripts `snake_case` and 1:1 with their scene where applicable.
- Input through named actions in `game/project.godot`, never raw keycodes.
- 960×540 base viewport, `canvas_items` stretch, `gl_compatibility` renderer.
- Tests are headless GDScript checks run with `--script`, printing
  `ALL PASS` and exiting non-zero on failure.
- Keep gameplay systems data-driven only where it reduces iteration cost; no
  premature frameworks.

## Must not

- Claim a test, scene or build passed without running it and reading output.
- Edit `vendor/superpowers/` or unrelated files.
- Skip the failing-check step because the change "looks trivial".
- Add scope that the approved design does not contain.
- Turn a **Proposed** value (balance, timing, cost) into a confirmed one.
