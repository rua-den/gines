# Map Stages — Design Brief

**Date:** 2026-11-21
**Author:** orchestrator (owner instruction: implement maps 02–08 one at a time, each with a full-map test)
**Status:** Proposed. No art direction, boss name, ability or milestone PASS is approved by this document.
**Milestone / phase:** Phase 4 map-runtime prototype, incremental per-map slices.

## Problem

`map_runner.tscn` proves that one JSON file can build one room, but it is
hard-wired to map01 (`map_runner.gd:14-18`): one map id, one fallback entity,
no motes, no evolution zone, no gate, no boss resolution, no retry. Making eight
copies of it would create eight divergent scripts and would not prove that a
player can traverse and finish a map.

In player terms: each remaining map must become a place a player can enter,
feed in, evolve in, fight through and exit — with a test that can prove the
whole path, one map at a time.

## Current state

- Implemented code: `PlayerController` (swim/crawl/grip, absorption, spike
  burst, energy), `Absorbable`, `Predator`, `EvolutionZone`, `BloomBoss`
  (telegraph → exposed weak window), `RoomBuilder`, `SaveState`.
- `region_slice.gd` proves the full loop prototype → boss arena via save handoff.
- `map_runner.gd` proves JSON → slabs → player → Predator for map01 only.
- Advisor A ruling: `map_runner` is not the per-map runner; use a parameterized
  stage builder. Implementation order: **03 → 02 → 04 → 05 → 06 → 07 → 08**.
- Advisor B ruling: "full map" needs smoke + headless regression + verifier lines;
  loadable is not traversable; fallbacks only where `fallback_until_implemented` exists.

## Approaches considered

| # | Approach | Verdict |
|---|---|---|
| 1 | Copy `map_runner.gd` per map | Rejected — eight divergent scripts, no boss/loop |
| 2 | Parameterized `MapStage` scene with `map_id`, plus one thin scene + one test + one verifier pair per map | **Chosen** |
| 3 | Edit `prototype.gd` / `boss_fight.gd` into a generic engine | Rejected — churns 21 verified checks |

**Chosen: approach 2.** New files only until a map proves it needs a change;
any change to an existing game file must be confirmed with an Advisor first.

## Design

`game/scripts/map_stage.gd` (`class_name MapStage extends Node2D`) loads
`res://resources/maps/<map_id>.json`, where `map_id` is exported on each thin
scene. It builds:
- every obstacle rect through `RoomBuilder.add_slab`; `gate` and `hazard_zone`
  become inert slabs (hazard damage is Open, never silently skipped);
- the player from `player.tscn` at `checkpoint.position`;
- three `Absorbable` motes (10 nutrition each = `EVOLVE_COST` 30) and one
  `EvolutionZone` before the gate;
- a boss entity: `BloomBoss` when `boss.id == "rot_bloom"`, otherwise the
  `built_from` fallback (`Predator`) — always labeled Proposed placeholder;
- a gate slab that opens only when the player is evolved, a following camera,
  a minimal HUD, shelter retry, and a completion marker after boss defeat.

Unsupported ids produce named failures instead of being skipped. A pure
`evaluate_map_stage(facts)` returns named failures for a headless test.

Per map: `game/scenes/mapNN.tscn`, `game/resources/maps/mapNN.json` (generated
copy of canonical `docs/maps/mapNN.json`, guarded by the checker's hash rule),
`game/tests/mapNN_check.gd`, and two `tools/verify.ps1` lines (smoke with
`\[MAPNN\] READY mapNN` pattern + regression with `ALL PASS`).

**Full-map test** means: JSON loads; slab rects equal JSON; player/motes/zone/
boss spawn; gate is closed before evolution and open after; burst deals 0 damage
outside the weak window and exactly 1 inside; completion marker waits for boss
defeat; retry preserves `evolved`/`nutrition` and resets boss health; player
stays in bounds while traversing the map's signature geometry. Each case must
be able to fail, including a negative fixture.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Implement maps 02–08 one at a time | Confirmed | Owner instruction 2026-11-21 |
| Parameterized MapStage, not eight runner copies | Proposed | Advisor A ruling |
| Order 03 → 02 → 04 → 05 → 06 → 07 → 08 | Proposed | Advisor A ruling; 03 uses only shipped code |
| Fallback entities where `fallback_until_implemented` exists | Proposed | Advisor B ruling; always labeled placeholder |
| Birth cinematic / combo mastery | Open | No approved design or art; map08 finale is a placeholder |
| Region visual identity, audio, animation | Open | `harness/project.md` Creative rules |

## Non-goals

- No new art, audio, animation, resource meter, save field or input action.
- No change to milestone decisions or to `docs/maps/*` canonical files.
- No claim that a placeholder boss is an approved enemy or that a map milestone passed.

## Anti-goals

- A "full map test" that only checks the scene loads.
- Silently skipping planned fields; duplicating a hard-coded runner per map.
- Two players/cameras/HUDs; softlocking an unevolved player behind a gate.

## Progression safety

Motes plus the evolution zone always make 30 nutrition available before the
gate; the gate opens only on `evolved`; energy regenerates; retry resets only
the boss and keeps progress. No permanent choice is introduced. `entry_requires`
is never fed to the loader as the real world graph.

## Acceptance

- [ ] Each implemented map has a scene, runtime JSON copy, headless test with
      exact case count, and two verifier lines (smoke + regression).
- [ ] The map test exercises the full loop and can fail on a broken rule.
- [ ] `tools/check_maps.ps1` passes with hash guards for every runtime copy.
- [ ] Full verifier and harness check stay green after each map.

## Risks

| Risk | Mitigation |
|---|---|
| Eight bosses vs. "multiple bosses out of scope" | Fallback placeholders, labeled Proposed; no production claim |
| Planned abilities faked | Named `unsupported` failures; Advised fallback-only rule |
| map08 cinematic cannot be honest | Explicit Open item; placeholder finale only |
| Scope creep / premature framework | One map at a time, full test gate before the next |

## Open questions

- Does the owner accept placeholder bosses for maps 02 and 04–08? — owner;
  changes whether those maps can be playable now.
- Which region identity and art direction should replace procedural shapes? — owner + Muse.
