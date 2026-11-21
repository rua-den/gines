# Final Boss Map (map09) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Two tasks: (1) FinalBoss + map09, (2) wiring/docs if needed. One reviewer per task.

**Goal:** Add a real, testable final boss map before birth, with a distinct two-phase boss and a full-map autopilot test.

**Architecture:** `FinalBoss` subclasses `BloomBoss` and overrides only health, timing durations and the second-wind transition. `MapStage` resolves boss id `the_convergence` to it. The ninth map reuses the existing data-driven stage pipeline; only the checker, menu and docs are widened from 8 to 9 maps.

**Tech Stack:** Godot 4.7.2, GDScript, headless tests, PowerShell checker/verifier.

**Spec:** `docs/superpowers/specs/2026-11-21-final-boss-map-design.md`

## Global Constraints

- Godot console: `D:\stu\gd\clone-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe`; repo root; args before `--`.
- New files: `game/scripts/final_boss.gd`, `game/scripts/final_boss.gd.uid`, `game/scenes/map09.tscn`, `game/resources/maps/map09.json`, `game/tests/map09_check.gd` (+ .uid), `docs/maps/map09.json`.
- Modify: `game/scripts/map_stage.gd` (map id + boss resolution only), `game/scripts/main_menu.gd` (10th entry), `game/tests/menu_check.gd` (count/paths), `tools/check_maps.ps1`, `tools/verify.ps1` (3 lines), `docs/maps/SCHEMA.md`, `docs/maps/REVIEW.md`, `docs/maps/map08.json` (exit → map09), `game/README.md`, `README.md`, `docs/BACKLOG.md`.
- Must not touch other game scripts/scenes, milestone verdicts, official design status tables, input map, save format.
- No art/audio/animation/birth cinematic/combo input.
- No milestone PASS, no art approval, no "fun" claim.

## Review Focus

- Boss really differs: 12 HP, phase-1 timings learned, second wind at half HP with shorter timings; still only vulnerable while exposed.
- Canonical chain 01→…→08→09→birth; checker enforces 9 maps.
- Menu lists 10 entries including map09.
- Full-map test falsifiable (zero-energy FAIL, boss health 0, negative fixtures).
- All earlier tests and demos stay green.

---

### Task 1: FinalBoss and map09

**Files:** create the new files; modify `map08.json`, `map09.json`, `map_stage.gd`, `check_maps.ps1`, `verify.ps1`, menu + menu test, docs.

- [ ] **Step 1: RED test first.** Write `game/tests/map09_check.gd` and any boss cases; run → missing `FinalBoss`. Cases: boss id/12 HP; phase-1 telegraph 0.6 / window 1.5; second wind at ≤6 HP → 0.45 / 1.1; damage only while exposed; defeat emitted once; map09 JSON load; slab rects; checkpoint; motes/zone; gate closed→open; burst outside 0 / inside 1; completion only after defeat; retry keeps progress + resets boss; zero-energy demo FAIL; drift; unsupported ids; 10-entry menu not required here.
- [ ] **Step 2: Implement.** `FinalBoss extends BloomBoss` with minimal overrides; `MapStage` resolves `the_convergence`; canonical `docs/maps/map09.json` (id map09, stage 9, entry_requires `map08.boss_defeated`, exit_unlocks `birth`, upgrade `final_form` grants `integrated_form` planned with fallback, boss `the_convergence` engine_status implemented); byte-exact runtime copy; `map08.json` exit_unlocks → `map09`. Thin `map09.tscn` scene with `map_id`, positions, `acknowledged_planned_grants = ["integrated_form"]`, honest `complete_text` (signpost toward birth, cinematic Open).
- [ ] **Step 3: Widen shared systems.** Checker: expected 9 files, loop 1..9, terminal check on map09, add `the_convergence` to implemented boss whitelist, hash guard map09. Menu: 10th entry map09; menu test paths/count 10. Verifier: 3 lines (smoke `\[MAP09\] READY map09`, regression `ALL PASS`, demo `MAP09 RESULT: PASS`). Docs: SCHEMA chain, REVIEW table + counts, README/BACKLOG counts.
- [ ] **Step 4: Verify.** `map09_check` ALL PASS; `final_boss` cases pass; smoke `[MAP09] READY map09`; demo `MAP09 RESULT: PASS` + zero-energy FAIL; menu_check ALL PASS; all 8 earlier map checks ALL PASS; checker PASSED (9 maps); verify full 47 / skip 36; harness 65.
- [ ] **Step 5: Review + commit.** `feat(map09): add final boss stage with two-phase convergence`.

---

## Verification summary

| Command | Expected |
|---|---|
| `map09_check.gd` | ALL PASS, exit 0 |
| menu_check.gd | ALL PASS, 10 entries |
| `check_maps.ps1` | PASSED — 9 maps, 541 checks |
| `verify.ps1 -SkipDemo` | 36 checks |
| full `verify.ps1` | 47 checks |
| `harness/scripts/check.ps1` | 65 checks |

No Phase 4 PASS or art approval claimed.
