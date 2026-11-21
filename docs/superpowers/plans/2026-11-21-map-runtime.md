# Map Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove that a design map JSON can drive a real Godot scene by adding a generic runner that loads `map01` and builds its geometry and entities.

**Architecture:** `MapRunner` reads a runtime JSON copy under `res://resources/maps/`, builds slabs through the existing `RoomBuilder`, spawns the shipped player and a Predator placeholder, and exposes a pure evaluator for headless assertions. `docs/maps/` remains canonical; a hash check detects drift. No existing game code is edited.

**Tech Stack:** Godot 4.7.2 stable, GDScript, headless `--script` checks, PowerShell verifier/checker.

**Spec:** `docs/superpowers/specs/2026-11-21-map-runtime-design.md`

## Global Constraints

- Godot console: `D:\stu\gd\clone-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe`; commands from repo root; engine args before `--`.
- New files only for Task 1: `game/scenes/map_runner.tscn`, `game/scripts/map_runner.gd`, `game/tests/map_runner_check.gd`, `game/resources/maps/map01.json` (verbatim copy of `docs/maps/map01.json`).
- Must NOT change: any existing `game/` script/scene, `game/project.godot`, `docs/maps/*`, milestone docs or design status tables.
- Reuse `RoomBuilder.add_slab`, `player.tscn`, `Predator`, input actions, existing HUD conventions. No new art/audio/animation/save field/input action.
- Unsupported ids must produce named failures, never be silently skipped.
- Runtime copy must be byte-identical to the canonical map; drift is a checker failure.
- No milestone PASS, no art approval, no claim that maps 02–08 work.
- Harness check must stay green.

## Review Focus

- **Data path** — geometry must come from JSON, not hard-coded coordinates; pinned by rect assertions.
- **Placeholder honesty** — planned boss spawns `Predator`, not `BloomBoss`; pinned by class assertion.
- **Unsupported ids** — missing fallback / unknown map rejected by name; pinned by negative fixtures.
- **Copy drift** — hash mismatch fails; pinned by fixture.
- **Bounds** — player never leaves the room; pinned by simulated frames.
- **Trivial pass** — every named case must be able to fail.

---

### Task 1: Runner, runtime map copy and headless rule test

**Files:**
- Create: `game/scenes/map_runner.tscn`, `game/scripts/map_runner.gd`, `game/tests/map_runner_check.gd`, `game/resources/maps/map01.json`

**Interfaces:**
- Consumes: `RoomBuilder.add_slab(parent, Rect2, color, edge)`, `player.tscn` (`PlayerController`), `Predator`, `SaveState`, JSON schema from `docs/maps/SCHEMA.md`.
- Produces: `[MAP] READY <id>` on load; members `map_data: Dictionary`, `slabs: Array`, `player`, `enemy`; pure `evaluate_map_run(facts: Dictionary) -> Array[String]`.

- [ ] **Step 1: Write the failing test first**
  `game/tests/map_runner_check.gd` (`extends SceneTree`, pattern of `energy_check.gd`) with helpers and cases:
  1. `runtime JSON loads and matches canonical id` — parsed `id == "map01"`, 4 obstacles.
  2. `slabs match JSON rects` — each `StaticBody2D` rect equals JSON rect within epsilon, collision layer 2.
  3. `player spawns at checkpoint` — position `[300,500]`, `evolved == false`, `nutrition == 0`.
  4. `planned boss uses Predator fallback` — enemy is `Predator`, not `BloomBoss`.
  5. `missing built_from is rejected` — named failure `no executable fallback`.
  6. `unsupported map id is rejected` — named failure `unsupported`.
  7. `runtime copy drift is rejected` — named failure `drift`.
  8. `player stays inside room bounds` — simulated frames, no out-of-bounds.
  Set `EXPECTED_CASES := 8`, print `ALL PASS` / exit 0-1. Every case must assert a real failure can fire, not just evaluator echo.

- [ ] **Step 2: Run it to confirm failure** — expect exit 1, missing `MapRunner`.

- [ ] **Step 3: Implement runner and copy the map**
  `class_name MapRunner extends Node2D`; in `_ready()` open `res://resources/maps/map01.json` via `FileAccess`, parse JSON, print `[MAP] READY <id>`, build slabs from `obstacles[]` with `RoomBuilder.add_slab`, instance `player.tscn` at `checkpoint.position`, instance `Predator` when `boss.built_from == "Predator"`, add following camera and minimal HUD. Implement pure `evaluate_map_run(facts)` returning named failures including `no executable fallback`, `unsupported`, `drift`, `bounds`. Create the scene with root `Node2D` named `MapRunner` and the script attached. Copy `docs/maps/map01.json` byte-for-byte to `game/resources/maps/map01.json`.

- [ ] **Step 4: Run tests and smoke**
  Test → `ALL PASS` 8 cases, exit 0. Smoke:
  `& $godot --headless --audio-driver Dummy --path game res://scenes/map_runner.tscn --quit-after 5` → `[MAP] READY map01`, exit 0.

- [ ] **Step 5: Regression** — `verify.ps1 -SkipDemo` still 16 checks; harness `HARNESS CHECK PASSED`.

- [ ] **Step 6: Commit** — `git commit -m "feat(map): add JSON-driven map runner for map01"`. Track the new `.uid` sidecars too.

---

### Task 2: Wire checker hash and verifier line

**Files:**
- Modify: `tools/check_maps.ps1` (one hash-equality check), `tools/verify.ps1` (one `Invoke-Check` line), `game/README.md` (short honest note: only map01 playable).

**Interfaces:**
- Consumes: canonical `docs/maps/map01.json`, runtime `game/resources/maps/map01.json`, `map_runner_check.gd`.

- [ ] **Step 1: Baseline** — checker passes (532 checks at start); verifier `-SkipDemo` 16 checks.
- [ ] **Step 2: Add hash check** to `tools/check_maps.ps1`: compare SHA256 of canonical and runtime map01; failure name `runtime map copy drifted from canonical`.
- [ ] **Step 3: Add verifier line** after `regression: region slice rules`: name `regression: map runner rules`, script `res://tests/map_runner_check.gd`, expected `ALL PASS`.
- [ ] **Step 4: Add README note** — map01 playable via `res://scenes/map_runner.tscn`; maps 02–08 are design-only; Predator is a placeholder.
- [ ] **Step 5: Verify** — checker still passes with new check; `-SkipDemo` 17 checks; full verifier 21 checks; harness 65 checks. Prove the hash check fails by temporarily editing the runtime copy, then restore.
- [ ] **Step 6: Commit** — `git commit -m "test(map): wire runtime copy drift and runner checks"`.

---

## Verification summary

| Command | Expected |
|---|---|
| `map_runner_check.gd` | `ALL PASS`, 8 cases, exit 0 |
| map runner smoke | `[MAP] READY map01`, exit 0 |
| `check_maps.ps1` | PASSED with hash check; drift fixture fails |
| `verify.ps1 -SkipDemo` | 17 checks |
| full `verify.ps1` | 21 checks |
| `harness/scripts/check.ps1` | `HARNESS CHECK PASSED` |

No Phase 4 PASS or approval is claimed; maps 02–08 remain design-only.
