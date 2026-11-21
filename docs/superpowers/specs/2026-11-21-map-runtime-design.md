# Map Runtime — Design Brief

**Date:** 2026-11-21
**Author:** agent (owner instruction: "có plan rồi giờ start làm map và game nhỉ")
**Status:** Proposed. This is an explicit scope change from "design-only maps"
authorized by the owner; it still approves no art, no new abilities and no
production of the remaining seven maps.
**Milestone / phase:** Phase 4 foundation proof, bounded to one map.
**Template:** `harness/templates/design-brief.md`

## Problem

The eight `docs/maps/mapNN.json` files are design artifacts: a validator checks
them, but `game/` contains no reference to any map and Godot never reads them.
The owner now wants maps to actually run. Building all eight would require dash,
glide, double-jump, hazard zones and combos that do not exist in the engine, so
the honest first step is to prove the **data → scene** path with one map whose
features already exist.

In player terms: load a map file, swim through its real obstacle layout, meet a
hostile organism, and read a HUD — with the geometry coming from JSON, not from
a hard-coded test room.

## Current state

- `docs/maps/map01.json`: four `static_slab` obstacles, upgrade `surface_grip` +
  `crawl` (both implemented in `player.gd`), planned boss `the_drifter` with
  `"built_from": "Predator"`.
- Reusable code: `RoomBuilder.add_slab`, `player.tscn`/`player.gd`, `Absorbable`,
  `Predator`, `EvolutionZone`, `Camera2D`, `SaveState`; input actions in `project.godot`.
- `game/resources/` exists and is the only place Godot can read `res://` JSON
  from; export-safe. OS absolute paths to `docs/maps/` are not.
- `tools/check_maps.ps1`: 532 checks, design-only, all fixtures fail correctly.
- `tools/verify.ps1`: 20 checks green, including the region slice.
- Decision rules: `harness/project.md` §§Decision rules, Scope guard.

## Approaches considered

| # | Approach | Player value | Solo cost | Verdict |
|---|---|---|---|---|
| 1 | Hard-code a scene that looks like map01 | Looks playable fastest | Low, but proves nothing about the data path | Rejected |
| 2 | Generic JSON runner, prove map01 only | Data → geometry → entity path proven; one real playable map | Modest: one scene, one script, one test, one runtime copy | **Chosen** |
| 3 | Load all eight maps | Full set | High: needs unimplemented abilities, art and boss code | Rejected — would fake completeness |

**Chosen: approach 2.** If any existing M0–M5 script or scene must be edited to
make this work, stop and report rather than churning verified code (Advisor
ruling, 2026-11-21).

## Design

`game/resources/maps/map01.json` is a **generated runtime copy** of the canonical
`docs/maps/map01.json`. A hash-equality check in `tools/check_maps.ps1` fails on
drift; the runtime copy is never hand-edited.

`MapRunner` (`game/scenes/map_runner.tscn`) loads `res://resources/maps/map01.json`
with `FileAccess`, validates required fields, then builds:
- one `StaticBody2D` slab per `obstacles[]` entry via `RoomBuilder.add_slab`,
  using the JSON rect and collision layer 2;
- one `PlayerController` from `player.tscn` at `checkpoint.position`;
- one hostile organism chosen from the boss block: `built_from: "Predator"`
  spawns a `Predator` — explicitly a **placeholder**, not an approved enemy;
- camera following the player and a minimal HUD reusing existing visual conventions.

Unsupported future ids (dash, glide, combos, hazard damage) are **rejected by
name** in `evaluate_map_run()` with a clear message; they are never silently
ignored. The runner exposes a pure `evaluate_map_run(...)` so headless tests can
pin the contract without a window.

No save-format change, no new input action, no new art/audio/animation.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Make maps runnable in Godot | Confirmed | Owner's explicit instruction 2026-11-21 |
| Prove map01 only with a generic runner | Proposed | Advisor ruling; smallest honest runtime path |
| `docs/maps/` canonical, `game/resources/maps/` generated copy | Proposed | Hash-equality check prevents drift |
| Predator as placeholder for `the_drifter` | Proposed | Follows `fallback_until_implemented` in the map data |
| Runtime map schema v1 | Proposed | Loader may cement it; schema changes are separate work |

## Non-goals

- No changes to `docs/maps/map*.json`, any existing `game/` script/scene,
  `project.godot`, milestone decisions or design status tables.
- No second map, no new ability, no art direction, no audio, no animation.
- No claim that maps 02–08 are playable.

## Anti-goals

- A runner that silently skips unsupported fields and looks complete.
- A runtime copy that drifts from the canonical design file without detection.
- Two players, two cameras or two HUDs; player leaving room bounds.
- Churning M0–M5 to make this work.

## Progression safety

map01 requires only already-implemented movement; the planned boss uses the
existing Predator fallback. No permanent choice, no new resource, no boss gate.
If the player exits room bounds, the test fails. There is no risk of softlock
because no required progression is introduced.

## Acceptance

- [ ] `game/scenes/map_runner.tscn`, `game/scripts/map_runner.gd`,
      `game/tests/map_runner_check.gd`, `game/resources/maps/map01.json` exist.
- [ ] Headless load of `res://resources/maps/map01.json` succeeds; parsed id and
      obstacle count match the canonical file.
- [ ] Exactly four `StaticBody2D` slabs with rects matching JSON within epsilon.
- [ ] Player spawns at `[300,500]`, unevolved, nutrition 0.
- [ ] A `Predator` spawns (not `BloomBoss`) for the planned boss block.
- [ ] Negative fixtures return named failures: invalid JSON, missing `built_from`,
      unsupported map id, runtime-copy hash drift.
- [ ] Simulated movement never leaves room bounds.
- [ ] `pwsh -File tools/check_maps.ps1` still passes with the new hash check;
      `verify.ps1` reports 17 checks with `-SkipDemo` / 21 full;
      harness check reports `HARNESS CHECK PASSED`.

## Risks

| Risk | Mitigation |
|---|---|
| Only 1 of 8 maps playable | State it in `game/README.md` and Open list; no completeness claim |
| Loader cements early schema | schema_version 1; changes are explicit separate work |
| Predator placeholder reads as approved enemy | Label Proposed/placeholder in brief and README |
| Runtime copy drift | Hash check in `tools/check_maps.ps1` |
| Premature framework | Stop if any existing game file needs editing |

## Open questions

- Should map02/03 be enabled at runtime next? — owner; changes scope.
- Region visual identity, audio, animation and the remaining abilities — owner + Muse; no approval exists.
