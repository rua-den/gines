# Campaign, Background and map01 Boss Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: subagent-driven-development. Two tasks, one implementer + one reviewer each.

**Goal:** Make map01's boss beatable, give map stages a procedural background, and add a sequential Campaign mode selectable from the menu.

**Architecture:** `map01.tscn` becomes another `MapStage` scene so the existing full-loop machinery (motes → evolution → gate → boss → completion) applies. A new `Campaign` node instances the nine map scenes one at a time and advances on `boss_defeated`. `MapStage` gains a shared procedural background builder. No autoload or save-format change.

**Tech Stack:** Godot 4.7.2, GDScript, headless tests, PowerShell verifier.

**Spec:** `docs/superpowers/specs/2026-11-21-campaign-and-visual-design.md`

## Global Constraints

- Godot console: `D:\stu\gd\clone-game\tools\godot\Godot_v4.7.2-stable_win64_console.exe`; repo root; args before `--`.
- Task 1 new: `game/scenes/map01.tscn`, `game/tests/map01_check.gd` (+ .uid). Modify `game/scripts/map_stage.gd` (map01 whitelist + background), `game/tests/map03_check.gd` (background case), `tools/verify.ps1` (3 lines), `game/scripts/main_menu.gd` (map01 path), `game/tests/menu_check.gd` (map01 path).
- Task 2 new: `game/scenes/campaign.tscn`, `game/scripts/campaign.gd`, `game/tests/campaign_check.gd` (+ .uid). Modify `main_menu.gd` (Campaign entry), `menu_check.gd`, `tools/verify.ps1` (3 lines), README/BACKLOG/game README.
- Must not touch: canonical `docs/maps/*`, milestone decisions, input map, save format, existing map02..09 scenes or tests.
- No new art/audio/font; procedural only. No birth cinematic.

## Review Focus

- map01 boss can really be defeated by the player (burst kills Predator), not just loaded.
- Background behind gameplay, falsifiable assertion, not a flat color.
- Campaign advances through all nine maps deterministically and can fail.
- Menu paths/count correct; verifier counts accurate; earlier checks green.

---

### Task 1: map01 full loop + procedural background

- [ ] Step 1 RED: write `map01_check.gd` with the map02-style full-loop cases plus a background case; run → missing scene.
- [ ] Step 2: implement `map01.tscn` (map_id map01, motes/zone/boss positions, acknowledged grants empty, complete_text honest), add `map01` to SUPPORTED_MAP_IDS, add `_build_background()` to MapStage with per-map tint and ≥2 radial blobs on layer -2.
- [ ] Step 3: add a background assertion case to `map03_check.gd` (bump EXPECTED_CASES) so shared background cannot be removed silently.
- [ ] Step 4: wire verifier 3 lines for map01; update menu map01 path to `map01.tscn` and its test expectation.
- [ ] Step 5: verify map01/map02/map03/menu checks ALL PASS, map01 smoke + demo PASS, checker 614, harness 65, verifier 50 full / 38 skip (47+3).
- [ ] Step 6: commit `feat(map01): add beatable boss stage and procedural backgrounds`.

### Task 2: Campaign mode

- [ ] Step 1 RED: write `campaign_check.gd` with cases: initial stage map01 ready; forcing `boss_defeated` advances to next stage; all nine advance to ending; ending appears only after map09; interactive back to menu; named negative fixture (unknown stage path / premature ending) fails.
- [ ] Step 2: implement campaign scene/script with `MAP_PATHS` for map01..map09, overlay labels, direct `_process()` polling (no physics-frame race), pure `evaluate_campaign(facts)`, `[CAMPAIGN] READY` log.
- [ ] Step 3: add Campaign entry to Main menu (6 entries) and update `menu_check.gd`; add 3 verifier lines.
- [ ] Step 4: verify campaign check ALL PASS, smoke, menu check ALL PASS, all map checks, verifier 53 full / 41 skip, checker 614, harness 65.
- [ ] Step 5: commit `feat(campaign): add sequential nine-map campaign mode`.

## Verification summary

| Command | Expected |
|---|---|
| map01/campaign/menu checks | ALL PASS |
| map01 smoke + demo | `[MAP01] READY map01` / `MAP01 RESULT: PASS` |
| campaign smoke | `[CAMPAIGN] READY` |
| `verify.ps1 -SkipDemo` | 41 checks |
| full `verify.ps1` | 53 checks |
| `check_maps.ps1` | 614 checks |
| harness | 65 checks |

No Phase 3/4 PASS or art approval claimed.
