# Final Boss Map (map09) — Design Brief

**Date:** 2026-11-21
**Author:** orchestrator (owner: "chưa có map đánh boss tổng nhỉ plan làm luôn nhé")
**Status:** Proposed. No art, audio or milestone approval is implied.
**Milestone / phase:** Phase 4 addition to the map runtime.

## Problem

The playthrough test from map01 to map08 succeeded (map01 smoke; map02–08
autopilot PASS), but every stage ends with either a Predator fallback or a
labeled BloomBoss placeholder. `docs/maps/map08.json:106` currently routes
straight to `birth`. There is no dedicated encounter that combines the player's
-learned movement, absorption, evolution and energy — Phase 2's "boss that
tests learned skills" exists only once, at map03.

In player terms: after the passage, the player should face one final hostile
organism whose rhythm demands everything learned, and only then see the route
to birth open.

## Current state

- Eight maps are runnable; verifier 44 checks, checker 540, harness 65.
- `BloomBoss` (`game/scripts/bloom_boss.gd`) has a precise, tested state machine:
  idle 0.4 s → telegraph 0.6 s → attack 0.25 s → exposed 1.5 s, 6 HP, damage
  only while exposed, joins the `predator` group.
- `MapStage` resolves bosses via whitelists; `rot_bloom` → BloomBoss, documented
  fallbacks → Predator or labeled BloomBoss placeholder.
- Menu Map Select has 9 entries (Region Slice + map01..08); checker expects 8 maps.
- `DEVELOPMENT_PLAN.md` §6: final stage is playable, birth is the culmination.
  Adding map09 before birth is a **Proposed extension** of that structure, not
  an approved design decision.
- The mother is never a boss (`GAME_DESIGN_FOUNDATION.md` §6/§11).

## Approaches considered

| # | Approach | Verdict |
|---|---|---|
| 1 | Give map08 a stronger BloomBoss by config only | Rejected — no new encounter; just retuned numbers |
| 2 | New `FinalBoss` subclass of `BloomBoss` with a second phase, plus map09 and its full-map test | **Chosen** |
| 3 | Build a boss from scratch with new mechanics/art | Rejected — high cost, no approved direction, risks the 44 green checks |

**Chosen: approach 2.** Reuse the proven state machine; the new content is one
subclass, one map JSON, one scene, one test and bounded wiring changes.

## Design

**Working name:** map09 "The Convergence"; boss `the_convergence` — a hostile
organism, explicitly **not** the mother or her body.

`FinalBoss extends BloomBoss`:
- `MAX_HEALTH := 12` (two times the standard boss).
- `TELEGRAPH := 0.6` and `WEAK_WINDOW := 1.5` in phase 1 (identical to the
  learned Rot Bloom rhythm).
- **Second wind** at ≤6 HP: telegraph shortens to 0.45 s, weak window narrows to
  1.1 s, and the lash/spore alternation speeds up. `phase_changed` carries a
  `second_wind` marker so HUD/test can read it.
- Same damage rule: only `attack` phase hurts, only `exposed` phase accepts
  damage; the existing `spike_burst` hits through the `predator` group.
- No new resource, no new input, no projectiles/hazards with damage.

Map09 layout: five slabs + a gate; the shelter checkpoint at `[300, 520]`;
three motes and an evolution zone before the gate, like other maps. Upgrade
`final_form` grants `integrated_form` (already a **planned** id) so the map
 loads through the two-tier planned-grant mechanism; no combo input is invented.
The final membrane becomes an inert slab placeholder as in map08.

Progression: map08 `exit_unlocks` changes from `birth` to `map09`; map09
`entry_requires = "map08.boss_defeated"` and `exit_unlocks = "birth"`. The birth
cinematic remains **Open** and is not implemented.

Wiring changes:
- checker: expect 9 maps, chain loop 1..9, map09 terminal `birth`, add
  `the_convergence` to the implemented boss whitelist and a hash guard for map09.
- menu: Map Select 10 entries (Region Slice + map01..09); test paths updated.
- `MapStage`: add `map09` and resolve `the_convergence` → `FinalBoss`.
- docs: SCHEMA chain rule, REVIEW table/rows, README/BACKLOG counts.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Add a ninth, dedicated final-boss map before birth | Proposed | Owner requested the plan/work; extends the Proposed 7–9 stage structure |
| FinalBoss subclasses BloomBoss with a second wind | Proposed | Reuses tested state machine; small code surface |
| 12 HP / 0.45 s telegraph / 1.1 s window in phase 2 | Proposed | Tuning values, not owner-approved |
| map08 now unlocks map09, map09 unlocks birth | Proposed | Changes canonical progression; recorded, not silently applied |
| Birth cinematic still Open | Confirmed by prior rulings | No cinematic invented |
| Mother never a boss | Confirmed | `GAME_DESIGN_FOUNDATION.md` §6/§11 |

## Non-goals

- No new art/audio/animation, no new resource meter, no new input action.
- No birth cinematic, combo input, or second evolution branch.
- No change to milestone decisions or official design status tables beyond the
  proposed map chain fields in `docs/maps/`.

## Anti-goals

- A "final boss" that is just the Rot Bloom with a higher HP number.
- A boss that can be killed by holding burst outside the exposed window.
- An unlabeled placeholder that implies approved content.
- Breaking the 44 verifier checks.

## Progression safety

The gate still requires evolution; three motes always provide 30 nutrition;
energy regenerates; shelter retry resets the boss and keeps evolution/nutrition.
The second wind only shortens timings — it never removes the weak window or
adds an untelegraphed kill. Fallback if the fight proves unbeatable: restore
phase-1 timings or lower HP; never add a mandatory new ability.

## Acceptance

- [ ] `game/scripts/final_boss.gd` + test cases proving 12 HP, second wind at
      ≤6 HP, phase-1 timings, phase-2 timings, damage only while exposed,
      defeat emitted once.
- [ ] `map09.json` canonical + byte-exact runtime copy; full-map test with
      autopilot `MAP09 RESULT: PASS` and a zero-energy FAIL negative control.
- [ ] Checker expects 9 maps and passes (541 checks expected); menu has 10
      entries and its test passes.
- [ ] Verifier full 47 checks / skip 36; harness 65; all earlier maps green.
- [ ] No milestone PASS, no art approval, no birth cinematic.

## Risks

| Risk | Mitigation |
|---|---|
| Subclass changes BloomBoss behavior | Keep overrides minimal; re-run map03 and boss regressions |
| Canonical chain change affects other docs | Update SCHEMA/REVIEW/README explicitly; state Proposed |
| Second wind too hard | Tunable constants; owner playtest decides |
| Scope creep to cinematics | Explicit non-goals; birth stays Open |

## Open questions

- Should the final boss have a third phase or an environmental hazard? — owner;
  changes code and animation cost.
- Should map09 replace map08 as "the finale" in narrative text? — owner.
