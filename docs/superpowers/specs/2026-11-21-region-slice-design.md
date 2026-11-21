# Region Slice — Design Brief

**Date:** 2026-11-21
**Author:** agent (owner instruction: "làm tiếp game nhé" — continue building the game)
**Status:** Proposed. No decision below is owner-approved art, scope or feel.
**Milestone / phase:** Phase 3 vertical slice, smallest integration slice.
**Template:** `harness/templates/design-brief.md`

## Problem

M0–M5 are implemented and their automated evidence is observed (VERIFY PASSED:
19 checks), but the game is still four separate test scenes: the M1 movement
room, the M2/M3/M4 prototype, the M5 boss arena and the M0 test scene. A player
cannot experience one continuous journey from absorbing the first mote to
winning the boss. `DEVELOPMENT_PLAN.md` §3 Phase 3 asks for one representative
polished section that "feels like a real game, not a technology demo."

In player terms: start as a vulnerable cell, feed, evolve, fight through the
arena with the body just grown, and see the route open — without a scene reload
or a README.

## Current state

- `game/scripts/player.gd`: swim/crawl/grip, absorption, health, spike burst,
  energy pool (`MAX_ENERGY` 3, cost 1, regen 1/s).
- `game/scripts/prototype.gd`: M2/M3 room with four motes, one predator, golden
  alcove at (1720, 420); saves `{evolved, nutrition}` via `SaveState`.
- `game/scripts/boss_fight.gd`: M5 arena, evolution gate that opens when a saved
  evolved player loads, shelter retry, `boss_defeated`, route gate.
- `game/scripts/save_state.gd`: stores only `evolved` and `nutrition`.
- `tools/verify.ps1`: 19 checks green, including M5 smoke and the windowed M5
  demo. No engine, art, audio or save-format change is needed for this slice.
- Decision rules and scope guard: `harness/project.md` §§Decision rules, Scope guard.

## Approaches considered

| # | Approach | Player value | Solo cost | Rules out | Verdict |
|---|---|---|---|---|---|
| 1 | Edit `prototype.tscn` and `boss_test.tscn` into one scene | Seamless space | High: churns M0–M5 code and risks the 19 green checks | Reusing verified scenes unchanged | Rejected |
| 2 | New integration scene that instances both existing scenes and hands progress through the existing save | One continuous loop using shipped systems; additive only | Modest: one scene, one script, one test | New art, new abilities, new systems | **Chosen** |
| 3 | Build a brand-new region from scratch | Full control over layout | High: duplicates room/HUD/boss work; no owner art direction | Revalidating every milestone | Rejected |

**Chosen: approach 2.** It is the smallest additive vertical slice. If instancing
either scene requires editing its script, stop and report rather than churning
M0–M5 (Advisor ruling, 2026-11-21).

## Design

**Working name:** the Region Slice. Not an approved region identity.

**Player loop:** instance the prototype room → feed three motes to 30 nutrition →
evolve at the alcove → deal with the predator using the new burst → reach the
right-hand boundary → save `{evolved, nutrition}` → free the prelude → instance
the boss arena → gate opens from loaded progress → read telegraph, burst in the
exposed window, shelter-retry on defeat → boss falls → route opens → a marker
reads `REGION COMPLETE — the path opens toward birth`. Slice ends.

**State machine:** `PRELUDE → ARENA → COMPLETE`. Only one room is instanced at a
time, so there is never a duplicate player, camera or HUD. The prelude instance
is freed before the arena is created.

**Save handoff:** the slice clears `user://genesis_save.cfg` on entry so a fresh
run is deterministic, then relies on `SaveState.write/read` — the same contract
M3/M5 already use. No save fields are added.

**Feedback:** existing HUDs, burst rings, boss phase labels and the existing
"NOW — strike the exposed core" prompt. No audio (no assets). Procedural visual
only; no frame-by-frame animation.

**Reused unchanged:** `player.gd`, `absorbable.gd`, `predator.gd`,
`evolution_zone.gd`, `burst_ring.gd`, `bloom_boss.gd`, `room_builder.gd`,
`save_state.gd`, `prototype.tscn`, `boss_test.tscn`, all input actions.

**New files only:** `game/scenes/region_slice.tscn`, `game/scripts/region_slice.gd`,
`game/tests/region_slice_check.gd`, one additive line in `tools/verify.ps1`.
Optionally a named demo capture set; not required for the first slice.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Owner instruction to continue the game | Confirmed | "làm tiếp game nhé", 2026-11-21; bounded to this slice by the scope guard |
| Integrate existing scenes via save handoff | Proposed | Advisor ruling; additive, no M0–M5 edits |
| Save cleared on slice entry | Proposed | Deterministic fresh run; long-term behavior Open |
| Region visual identity | Open | Reuse procedural palettes only; no approved art direction |
| Second evolution / branch / loadout | Open | `DEVELOPMENT_PLAN.md` §5; out of scope |
| Boss values and "feel" | Open | M5 owner playtest still open |
| Audio / frame animation | Open | No assets; explicitly deferred |
| End marker means "route opens" | Proposed | Signpost only, not the birth cinematic (`DEV §6`) |

## Non-goals

- No new gameplay system, ability, enemy, boss, resource or save field.
- No edit to any existing scene, script, `project.godot`, milestone decision or
  design status table.
- No art-direction approval; no Muse concept promoted.
- No claim that Phase 3 passed or that the slice is fun — that is owner playtest.

## Anti-goals

- Two players, two cameras or two HUDs alive at once.
- A transition that fires while the player is unevolved and strands them in an
  unwinnable arena.
- A "region complete" marker that can appear before the boss is defeated.
- Rewriting M0–M5 to make the integration work.

## Progression safety

The transition requires `evolved == true`, mirroring the M5 evolution gate. If
the player is unevolved at the boundary, nothing happens. Evolution and
nutrition are saved before the arena loads, so the arena gate opens for free;
shelter retry keeps them. Energy regenerates at 1/s and is never a gate. The
boss is never saved. If the integration cannot be done without editing existing
scripts, the slice stops and reports rather than risking the 19 verified checks.

## Acceptance

- [ ] `game/scenes/region_slice.tscn` and `game/scripts/region_slice.gd` exist;
      the scene loads headlessly and prints a recognisable `[SLICE] READY` line.
- [ ] A fresh run starts unevolved with nutrition below `EVOLVE_COST`.
- [ ] Reaching the boundary while unevolved does **not** transition; evolving
      first does.
- [ ] After transition: exactly one player and one current camera; prelude
      instance freed; arena instance present; arena gate open and boss has its
      player.
- [ ] Burst outside the exposed window leaves boss health unchanged; inside it
      subtracts exactly one.
- [ ] End marker is inactive before defeat and completion is reported once.
- [ ] Shelter retry preserves `evolved`/`nutrition` and resets boss health.
- [ ] `game/tests/region_slice_check.gd` returns named failures for each broken
      case above; `pwsh -File tools/verify.ps1 ... -SkipDemo` reports 16 checks
      (existing 15 + the new regression), and the full 20-check run stays green.
- [ ] `pwsh -File harness/scripts/check.ps1` still reports `HARNESS CHECK PASSED`.

## Risks

| Risk | Mitigation |
|---|---|
| Instancing both scenes duplicates HUD/camera/input | Instance one at a time, free prelude before arena; stop if existing scripts need edits |
| Save handoff clears a real player's progress | Documented Open behavior; slice is a test scene, not the shipping game flow |
| Linear corridor vs. Confirmed interconnected world | Recorded Open/Risk; `progression.model: illustrative_linear` remains |
| End marker read as the birth ending | Label says route opens toward birth; no birth cinematic implemented |
| Slice proves integration, not fun | Owner playtest checklist required; no PASS claim by an agent |

## Open questions

- Does the owner accept clearing the save on slice entry? — owner; changes only
  test-scene ergonomics.
- Which region identity, second evolution and art direction should the real
  vertical slice use? — owner + Muse; needed before content production.
