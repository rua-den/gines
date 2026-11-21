# Campaign, Background and map01 Boss — Design Brief

**Date:** 2026-11-21
**Author:** orchestrator (owner feedback: no campaign, flat backgrounds, map01 boss cannot be defeated)
**Status:** Proposed. No approved art direction; backgrounds stay procedural.
**Milestone / phase:** Phase 3/4 player-facing completeness.

## Problem

Playing the build reveals three concrete defects:
1. Menu opens standalone scenes; there is no way to play map01→map09 in one session.
2. Map stages draw only slabs and HUD on a flat color — the world looks empty.
3. `map_runner.gd` (map01) spawns a Predator but no motes, evolution zone or
   burst, so `the_drifter` cannot be defeated at all. The map claims a boss that
   is mechanically unreachable.

## Current state

- `map_runner.gd:45-51` builds slabs, player, Predator only; `evaluate_map_run`
  never checks an achievable boss kill.
- `map_stage.gd:456-465` builds slabs/player/motes/zone/boss/camera/HUD; no
  `_build_background()` exists.
- `main_menu.gd:27-37` has Region Slice + map01..map09; no Campaign entry.
- All 9 maps have their own full-map test and autopilot; verifier 47 checks;
  checker 614; harness 65.
- No art/audio/font assets; procedural gradients are the only honest option.

## Approaches considered

| # | Approach | Verdict |
|---|---|---|
| 1 | Link scenes with a global autoload carrying evolution/nutrition | Rejected — new architecture, save/state churn, risks 47 green checks |
| 2 | Campaign scene that loads each existing map scene in order; each map stays self-contained; advance on `boss_defeated` | **Chosen** |
| 3 | Add backgrounds as authored images | Rejected — no approved direction, no assets, high cost |

**Chosen: approach 2** plus: make map01 use the same full-loop `MapStage` as
maps 02–09 so its boss is actually beatable, and add a procedural layered
background to the shared stage.

## Design

### Campaign

`game/scenes/campaign.tscn` + `campaign.gd`: owns an ordered array of the nine
map scenes. It instances one at a time, waits for that stage's `boss_defeated`
(and completion marker) via polling, shows a short `STAGE N COMPLETE` overlay,
then advances. After map09 it shows `THE PATH OPENS TOWARD BIRTH` (signpost
only — birth cinematic remains Open) and returns to the menu on `interact`.
Each map remains self-contained; no cross-map inventory or save format is
introduced. A headless test drives each stage by setting `boss_defeated` and
asserts advancement through all nine plus a negative fixture.

Menu: add **Campaign** to Main (New Game / Continue / Campaign / Map Select /
Quit), taking Main from 4 to 5 entries. Map Select still lists all nine maps.

### Per-stage pause menu

The owner also reported there is no way to go back from a stage. `MapStage`
gains a pause overlay shown with `pause` (`Esc/P`): **Resume**, **Restart**,
**Map Select**, **Main Menu**. `move_up/down` selects, `interact` activates,
`pause`/`attack` resumes. Restart reloads the current map from its JSON;
Map Select and Main Menu request the corresponding main-menu panel. The
overlay must pause gameplay while open and never destroy the player's saved
progress. It is tested by a dedicated case in `map03_check.gd` (shared code):
open on `pause`, Resume closes it, Restart rebuilds one player/camera, and the
two navigation requests produce the correct targets. This is a Proposed
quality-of-life feature, not an approved UI art direction.

### map01 beatable

Add `game/scenes/map01.tscn` using `MapStage` with `map_id = "map01"`, motes,
zone and boss positions; add `map01` to `SUPPORTED_MAP_IDS`. Its planned boss
`the_drifter` resolves through the existing `built_from: Predator` fallback.
The old `map_runner.tscn` stays as the JSON data-path proof but is no longer the
menu's map01 entry. Add `map01_check.gd` mirroring `map02_check.gd` with the
full loop (feed → evolve → gate → burst down Predator → completion).

### Background

Add `_build_background()` to `MapStage`, shared by all maps: a `CanvasLayer`
at layer -2 with a dark base `ColorRect`, 2–3 large translucent radial-gradient
blobs and a soft horizontal band, reusing the procedural texture approach in
`prototype.gd`. No new asset, no approved art claim. Tint varies with `map_id`
via a small color table so regions are not identical. Test: at least one
background layer node with `layer == -2` and ≥2 visible gradient sprites; pin in
`map03_check.gd` (shared code) so a removal fails.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Sequential campaign without shared inventory | Proposed | Bounded; avoids save-format/architecture churn |
| map01 moves to MapStage with real feed/evolve/boss loop | Proposed | Fixes unreachable boss honestly |
| Procedural layered backgrounds, per-map tint | Proposed | No approved art direction; exploration only |
| Background tint table keyed by map_id | Proposed | Data-light; no new resource type |

## Non-goals

- No autoload, no cross-map save/loadout, no birth cinematic.
- No authored art, audio or animation.
- No new boss behavior beyond existing fallbacks.

## Anti-goals

- A "campaign" that is just a menu list.
- A map with a boss that cannot be damaged.
- A flat single-color playfield called a background.

## Progression safety

Each map keeps its own three motes + zone gate, so a player can always reach
and defeat the boss. Campaign only sequences scenes; it never locks a stage
behind a resource that cannot regenerate. Fallback if a stage cannot be
completed: skip it in the campaign test and report, never force progression.

## Acceptance

- [ ] `map01_check.gd` ALL PASS including burst killing the Predator.
- [ ] Menu has a Campaign entry; `menu_check.gd` updated and ALL PASS.
- [ ] `campaign_check.gd` drives all nine stages to completion with a named
      negative fixture; `campaign.tscn` smoke prints `[CAMPAIGN] READY`.
- [ ] Per-stage pause overlay in `MapStage` tested via `map03_check.gd`: opens,
      resumes, restarts with one player/camera, and requests Map Select / Main.
- [ ] Background nodes asserted in at least one map test.
- [ ] Verifier full 53 / skip 41; checker 614; harness 65; all earlier tests green.
- [ ] No milestone PASS, no approved art, no birth cinematic.

## Risks

| Risk | Mitigation |
|---|---|
| Campaign polling races completion | Drive `_process()` directly in tests like the region-slice fix |
| Background hurts readability | Low-opacity, behind gameplay, assert layer -2 |
| map01 change breaks its existing runner test | Keep map_runner untouched; add new map01 stage separately |

## Open questions

- Should campaign carry evolution/nutrition between maps? — owner; changes scope
  and would need a save/autoload design.
