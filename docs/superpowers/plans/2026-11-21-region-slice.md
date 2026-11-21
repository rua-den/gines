# Region Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one additive, headlessly verifiable vertical slice that connects the existing M1–M4 prototype room to the existing M5 boss arena as a single playable loop.

**Architecture:** A new `RegionSlice` scene instances `prototype.tscn` (`PRELUDE`) and, after a save handoff, `boss_test.tscn` (`ARENA`), never both at once. It exposes a pure `evaluate_slice_run(...)` so headless tests can assert rules without a window. No existing script or scene is edited.

**Tech Stack:** Godot 4.7.2 stable, GDScript, headless `--script` checks, PowerShell verifier.

**Spec:** `docs/superpowers/specs/2026-11-21-region-slice-design.md` (read alongside; every value is **Proposed**).

## Global Constraints

- Godot **4.7.2 stable console** at `D:\stu\gd\clone-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe`; not on PATH; commands from repo root; engine args before `--`.
- New files only for Task 1: `game/scenes/region_slice.tscn`, `game/scripts/region_slice.gd`, `game/tests/region_slice_check.gd`. Task 2 may add exactly one line to `tools/verify.ps1`.
- Must NOT change: any existing `game/` script or scene, `game/project.godot`, `check_maps.ps1`, `docs/MILESTONES.md`, `DEVELOPMENT_PLAN.md`, `GAME_DESIGN_FOUNDATION.md`, `docs/maps/*`.
- No new art, audio, animation, resource type, save field or input action.
- Reuse `SaveState` (`{evolved, nutrition}` only), `PlayerController`, `Absorbable`, `Predator`, `EvolutionZone`, `BloomBoss`, `RoomBuilder`.
- One player and one current camera at any time; free the prelude before instancing the arena.
- No agent writes a milestone verdict or claims the slice is fun. No PASS claim without an observed run.
- `pwsh -File harness/scripts/check.ps1` must keep reporting `HARNESS CHECK PASSED`.

## Review Focus

- **Unevolved transition** — reaching the boundary unevolved must not transition; pinned by a named test case.
- **Duplicate actors** — exactly one player and one current camera after transition; pinned by a named case.
- **Save handoff** — arena loads with `evolved == true` and an open gate; pinned by a named case.
- **Burst damage gating** — outside exposed window no boss damage, inside exactly one; pinned by a named case.
- **Completion timing** — end marker inactive until `boss_defeated`, completion reported once; pinned by a named case.
- **Retry safety** — shelter retry keeps evolution/nutrition and resets boss health; pinned by a named case.
- **Verifier truth** — new check must be able to fail; no predicted PASS in reports.

---

### Task 1: Region slice scene, controller and headless rule test

**Files:**
- Create: `game/scenes/region_slice.tscn`, `game/scripts/region_slice.gd`, `game/tests/region_slice_check.gd`

**Interfaces:**
- Consumes: `prototype.tscn` (instance exposes `player`, `zone`, `motes`, `predator`), `boss_test.tscn` (instance exposes `player`, `boss`, `boss_defeated`, `retry()`), `SaveState.clear/write/read`, `PlayerController.EVOLVE_COST`, `BloomBoss.MAX_HEALTH`.
- Produces: `[SLICE] READY` on load; members `state: String`, `prelude`, `arena`, `completion_reported: bool`; method `evaluate_slice_run(facts: Dictionary) -> Array[String]` returning named failures; signal not required.

- [ ] **Step 1: Write the failing test first**
  In `game/tests/region_slice_check.gd` (`extends SceneTree`, following `energy_check.gd`): add helpers `_frames(n)`, `_check(label, ok, detail)`, `_make_slice()` and cases:
  1. `fresh run starts unevolved and underfed` — facts: `evolved=false`, `nutrition < EVOLVE_COST`.
  2. `unevolved at the boundary does not transition` — call `evaluate_slice_run` with `at_boundary=true, evolved=false`; expect a failure naming the transition rule.
  3. `evolved at the boundary transitions` — with `evolved=true`, no transition failure.
  4. `exactly one player and camera after transition` — facts include `player_count`, `current_camera_count`, both must be 1.
  5. `arena loads with an open gate and a boss player` — `gate_open=true`, `boss_has_player=true`.
  6. `burst outside the weak window deals no boss damage` — `outside_damage=0`.
  7. `burst inside the weak window deals exactly one` — `inside_damage=1`.
  8. `completion marker waits for defeat and fires once` — `marker_before_defeat=false`, `completion_count=1`.
  9. `retry preserves progress and resets the boss` — `evolved=true`, `nutrition>=0`, `boss_health=BloomBoss.MAX_HEALTH`.
  Set `EXPECTED_CASES := 9`; print `ALL PASS` / exit 0/1 like `energy_check.gd`.

- [ ] **Step 2: Run it to confirm it fails**
  `& $godot --headless --audio-driver Dummy --path game --script res://tests/region_slice_check.gd`
  Expected: exit 1, missing `RegionSlice` identifier.

- [ ] **Step 3: Implement `region_slice.gd` and the scene**
  `class_name RegionSlice extends Node2D`. In `_ready()`: clear the save, print `[SLICE] READY`, instance `prototype.tscn` as `prelude`, set `state = "PRELUDE"`. In `_process()`: poll the prelude player's `global_position.x >= 1880.0` and `evolved`; only when both are true, write `SaveState.write({evolved, nutrition})`, free the prelude, instance `boss_test.tscn` as `arena`, set `state = "ARENA"`. Poll `arena.boss_defeated`; on first true, add a `Label` reading `REGION COMPLETE — the path opens toward birth`, set `state = "COMPLETE"`, set `completion_reported = true`. Use dynamic `get("player")` etc.; do not edit other scripts. Implement `evaluate_slice_run(facts)` as a pure function returning the named failures for the cases above.
  Create `region_slice.tscn` with root `Node2D` named `RegionSlice` and the script attached.

- [ ] **Step 4: Run the test and a scene smoke**
  Run the check again → `ALL PASS`, exit 0, 9 cases. Then
  `& $godot --headless --audio-driver Dummy --path game res://scenes/region_slice.tscn --quit-after 5`
  → exit 0, prints `[SLICE] READY`, no errors.

- [ ] **Step 5: Full regression**
  `pwsh -File tools/verify.ps1 -Godot $godot -SkipDemo` → still `VERIFY PASSED: 15 checks`.
  `pwsh -File harness/scripts/check.ps1` → `HARNESS CHECK PASSED`.

- [ ] **Step 6: Commit**
  `git add game/scenes/region_slice.tscn game/scripts/region_slice.gd game/tests/region_slice_check.gd`
  `git commit -m "feat(slice): add continuous prototype-to-boss region slice"`

---

### Task 2: Wire the slice regression into the verifier

**Files:**
- Modify: `tools/verify.ps1` (exactly one added check line)

**Interfaces:**
- Consumes: `game/tests/region_slice_check.gd` from Task 1.
- Produces: a 16th check in `-SkipDemo` mode, 20th in full mode.

- [ ] **Step 1: Record baseline** — run `pwsh -File tools/verify.ps1 -Godot $godot -SkipDemo`, expect `VERIFY PASSED: 15 checks`.
- [ ] **Step 2: Add one `Invoke-Check` line** after the M5 demo verdict regression:
  Name `regression: region slice rules`, script `res://tests/region_slice_check.gd`, expected `ALL PASS`. Do not change any other line.
- [ ] **Step 3: Verify** — `-SkipDemo` → `VERIFY PASSED: 16 checks`; full verifier → `VERIFY PASSED: 20 checks`.
- [ ] **Step 4: Commit** — `git commit -m "test(verify): wire region slice rule check"`

---

## Verification summary

| Command | Expected |
|---|---|
| `region_slice_check.gd` | `ALL PASS`, 9 cases, exit 0 |
| region slice scene smoke | `[SLICE] READY`, exit 0 |
| `verify.ps1 -SkipDemo` | `VERIFY PASSED: 16 checks` |
| full `verify.ps1` | `VERIFY PASSED: 20 checks` |
| `harness/scripts/check.ps1` | `HARNESS CHECK PASSED` |

This plan produces an integration slice only. It does not declare Phase 3 PASS,
approve art, or claim the slice is fun; those remain owner decisions.
