# Map Stages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Each map is one task with a fresh implementer and a task review before the next map starts.

**Goal:** Make maps 03, 02, 04, 05, 06, 07, 08 runnable one at a time, each with a headless test that exercises the full map loop.

**Architecture:** One parameterized `MapStage` scene/script loads `res://resources/maps/<map_id>.json` and builds geometry, motes, evolution zone, gate, boss, camera, HUD, retry and completion. Each map adds a thin scene with an exported `map_id`, a generated runtime copy, a per-map rule test, and two verifier lines. No existing game file changes without an Advisor ruling.

**Tech Stack:** Godot 4.7.2 stable, GDScript, headless `--script` checks, PowerShell verifier/checker.

**Spec:** `docs/superpowers/specs/2026-11-21-map-stages-design.md`

## Global Constraints

- Godot console: `D:\stu\gd\clone-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe`; repo root; engine args before `--`.
- Canonical maps stay in `docs/maps/`. Runtime copies go to `game/resources/maps/mapNN.json`, byte-identical (checker hash guard).
- New files per map: `game/scenes/mapNN.tscn`, `game/resources/maps/mapNN.json`, `game/tests/mapNN_check.gd` (+ `.uid`), and in Task 1 only `game/scripts/map_stage.gd` (+ `.uid`).
- `tools/verify.ps1`: two additive lines per map (smoke with `\[MAPNN\] READY mapNN`, regression with `ALL PASS`).
- No new art/audio/animation/save field/input action. No edit to milestone docs or canonical maps.
- Unsupported future ids must return named failures; never silently skip.
- Every per-map test must include a negative fixture that fails for the right reason.
- M4/M5 human checks stay Open; no milestone PASS, no art approval, no "fun" claim.

## Review Focus

- Full loop, not just load: motes → evolution → gate → boss → completion → retry.
- Gate cannot be opened by an unevolved player; exactly one player/camera/HUD.
- Boss damage only inside weak window; planned bosses use documented fallbacks and stay labeled Proposed.
- Slab rects come from JSON; runtime copy hash matches canonical.
- Unsupported ids rejected by name; negative fixture exits 1.
- Existing 21 verifier checks and 533 map checks stay green.

---

### Task 1: Parameterized stage + map03

**Map 03** is first because its upgrade (`spike_ring`/`spike_burst`) and boss
(`rot_bloom`) already exist in code (Advisor A).

**Files:** create `game/scripts/map_stage.gd`, `game/scenes/map03.tscn`, `game/resources/maps/map03.json`, `game/tests/map03_check.gd`; modify `tools/verify.ps1` (2 lines), `tools/check_maps.ps1` (hash guard for map03).

- [ ] Step 1: write `map03_check.gd` first with cases: JSON loads + 4 slabs match rects; player at checkpoint; three motes + zone present; gate closed before evolution and open after; boss is BloomBoss; burst outside weak window deals 0 / inside deals exactly 1; completion marker only after defeat; retry preserves progress and resets boss; player traverses to the gate without leaving bounds; unsupported map id rejected by name. Run → RED.
- [ ] Step 2: implement `map_stage.gd` and the thin scene; copy `docs/maps/map03.json` byte-for-byte.
- [ ] Step 3: run test → ALL PASS; scene smoke → `[MAP03] READY map03`; full-map autopilot reaches completion with `MAP03 RESULT: PASS` (named captures if a window exists; headless reports FAIL by design and is skipped from `-SkipDemo`).
- [ ] Step 4: wire two verifier lines + hash guard. Checker still passes; `-SkipDemo` +2; full verifier +2 + demo.
- [ ] Step 5: review by fresh subagent; fix loop if needed; commit `feat(map03): add runnable JSON-driven stage with full-map test`.

### Tasks 2–7: maps 02, 04, 05, 06, 07, 08

Same shape as Task 1, reusing `map_stage.gd` with no new script:
- [ ] Step 1: write `mapNN_check.gd` with the same core cases plus the map's signature geometry (02 slits, 04 bend, 05 low tunnel, 06 platforms, 07 upper ledge, 08 constriction). RED first.
- [ ] Step 2: add thin scene + byte-identical runtime copy. Boss = `built_from` fallback (`Predator`) unless `rot_bloom`; hazard zones are inert slabs.
- [ ] Step 3: test ALL PASS; smoke `[MAPNN] READY mapNN`; full-map autopilot completion; note explicitly that planned abilities/bosses remain placeholders.
- [ ] Step 4: two verifier lines + hash guard; all prior checks green.
- [ ] Step 5: review; commit `feat(mapNN): add runnable stage with full-map test`.

**map08 exception:** the birth cinematic and combo mastery have no approved design; implement the finale as a clearly labeled placeholder ending (`REGION COMPLETE — the path opens toward birth`), and record the cinematic as Open. Do not invent one.

## Confirmation protocol

Implementers may not dispatch subagents. If a decision exceeds the brief, report
`NEEDS_CONTEXT` with: map id, exact diff, first failing test, observed command
output, entity/fallback status, new ids vs whitelists, and the precise question.
The orchestrator relays it to Advisor A (progression/abilities) or Advisor B
(runtime/QA/test shape), then resumes the implementer with the ruling.

## Verification summary

After each map: mapNN_check `ALL PASS`; smoke pattern; full-map autopilot PASS;
checker PASSED with new hash guard; verifier +2 checks; harness 65 checks; commit.
Final target: 21 + 14 = 35 verifier checks (7 maps × 2) plus map08 demo handling.

No Phase 4 PASS or art approval is claimed at any step.
