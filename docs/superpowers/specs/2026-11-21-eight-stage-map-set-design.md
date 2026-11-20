# 8-Stage Map Set — Design Brief

**Date:** 2026-11-21
**Author:** agent (under the owner's standing "keep going and invent what is missing" instruction)
**Status:** Proposed — nothing here is an owner-approved production decision.
**Milestone / phase:** Design artifact for a future Phase 4 / Phase 5 world; current gate remains Phase 2 (M5 owner playtest open).
**Template:** `harness/templates/design-brief.md`

## Problem

The owner asked for a design of 8 playable stages, each with obstacles, one
upgrade taken from the existing plan, and one boss, split into `map<NN>.json`
files and then reviewed. Today there is no world map: geometry lives as constants
in `game/scripts/room_builder.gd`, and the only playable spaces are the M1/M2
test room and the M5 boss arena. Without a written map set there is no shared
object to review for progression safety, pillar alignment or softlocks before
content production starts.

In player terms: the journey from a single cell to birth needs eight distinct
places where a new body capability is earned, tested against a threat, and then
used to reach the next place. "More content" alone is not the value — the value
is a checkable progression chain.

## Current state

- `docs/DEVELOPMENT_PLAN.md` §2: "7–9 developmental stages" is **Proposed / Risk**;
  `docs/GAME_DESIGN_FOUNDATION.md` §11 agrees the structure may be consolidated.
- `docs/BACKLOG.md`: "Full world map", "multiple complete regions", "all
  developmental stages" and "multiple bosses" are **explicitly out of scope**
  for the prototype. This design is therefore a design exploration, not a
  commitment to build eight bosses now.
- `docs/DEVELOPMENT_PLAN.md` §7 progression: early swim/crawl/grip/contraction/
  hiding → later run/jump/double-jump/dash/glide/body-part weapons/biological
  powers/combos. §5: 4–5 evolution branches, permanent choices, equipped
  capacity, and a hard requirement that no permanent choice softlocks progress.
- §4 resources: five named resources, but §4's validation requirement says not to
  implement five meters until each earns a distinct purpose. The build has one:
  `player.nutrition` (`save_state.gd` stores only `evolved` and `nutrition`).
- Implemented in code (design values still **Proposed**): M1 swim/crawl/grip,
  M2 absorption + survival, M3 spike ring + burst, M4 energy pool, M5 Rot Bloom
  boss with evolution gate, shelter retry and weak-window damage gating
  (`game/scripts/boss_fight.gd`, `bloom_boss.gd`, `room_builder.gd`).
- No map JSON format exists anywhere in the repo; no loader exists.
- Decision vocabulary and gate rules: `harness/project.md` §"Decision rules",
  `docs/DEVELOPMENT_PLAN.md` §9.

## Approaches considered

| # | Approach | Player value | Solo cost | Rules out | Verdict |
|---|---|---|---|---|---|
| 1 | Design-only JSON in `docs/maps/` plus a hand-written review | Reviewable chain, zero code | Lowest | Automated evidence | Rejected — review cannot fail |
| 2 | JSON in `game/data/maps/` plus a Godot loader and headless test | Ready for Phase 4 | Medium; new loader and schema in the engine | Nothing, but implies a system that does not exist | Rejected — overbuilds the current gate |
| 3 | JSON in `docs/maps/`, documented schema, checkable invariants, review report with observed output | Reviewable chain plus evidence that can fail | Medium-low: 8 data files, one PowerShell checker, one review doc | Loader (deliberately) | **Chosen** |

**Chosen: approach 3** — the owner picked the "Design + validator" option. It
matches a pre-production gate, produces review evidence that can actually fail,
and keeps the door open to copy the same JSON into `game/data/maps/` in Phase 4.
No loader is written, so nothing can be mistaken for an implemented system.

## Design

### Deliverables

- `docs/maps/map01.json` … `docs/maps/map08.json` — one stage each.
- `docs/maps/SCHEMA.md` — field contract and the invariant list the checker enforces.
- `tools/check_maps.ps1` — headless, dependency-free PowerShell validator; prints
  `MAP CHECK PASSED` or a numbered failure list and exits 0/1.
- `docs/maps/REVIEW.md` — per-map review table plus the **observed** checker
  output. This is a design review, not a milestone verdict.

### The eight stages (working names, not approved art direction)

| # | Working name | Developmental beat | Obstacles | Upgrade (plan ref) | Boss (hostile organism) | Stage status |
|---|---|---|---|---|---|---|
| 01 | The First Cell | fertilisation, first movement | membrane slabs, crawl slit, floating platform | `surface_grip` + `crawl` (§7 early; M1) | The Drifter — amoeboid, weak window when its vacuole opens | partial |
| 02 | The Divide | cleavage | narrow crawl slits, dividing pillars | `absorption_channel` + `nutrition` (§7 early; M2) | The Splitter — divides at half health, forcing feeding under pressure | partial |
| 03 | The Golden Alcove | implantation, first permanent body change | evolution gate wall, platform, vertical pillar (M5 geometry) | `spike_ring` + `spike_burst` (§5/§8; M3) | The Rot Bloom — 6 HP, telegraph → exposed 1.5 s (M5) | implemented |
| 04 | The Pulse | rhythm and restraint, heartbeat as a sparse cue | pulsing membrane slabs, hazard zone, bends | `energy_pool` (§7 "special abilities may consume energy"; M4) | The Pulse Maw — rhythmic burst attacker, punishes holding attack | partial |
| 05 | The Calcium Vault | mineral deposition, first rigid structure | hard pillars, ceiling spikes, low grip tunnel | `body_contraction` → dash (§7 contraction/dash) | The Vine Lash — rooted tendril, long telegraph, dash opens the dodge | planned |
| 06 | The Budding Field | limb buds | gaps, vertical walls, floating platforms | run + jump + directional body-part strike (§7 later movement/weapons) | The Gnawer — armoured front, strike only in its weak window | planned |
| 07 | The Neural Bloom | senses and coordination | tall shafts, long gaps, sensor tripwires | double-jump + glide + optional `chemical_veil` (§7 gliding/hiding/powers) | The Sentinel — tracks the player; veil or glide are both valid answers | planned |
| 08 | The Passage | birth, final playable stage | constricting slabs, final membrane gate | `integrated_form` — combo mastery (§7 combos, mastery combat) | The Last Overgrowth — cellular tangle, all prior abilities; mother's heartbeat guides, never fights | planned |

Every stage carries: ≥2 `static_slab` obstacles, exactly one `upgrade` block,
exactly one `boss` block, one `shelter` checkpoint, one `resources` block and one
`narrative` block. Stage 01 has no entry requirement; stage N's `exit_unlocks`
equals stage N+1's id; stage 08's exit is the birth cinematic.

**Builder calls recorded (from the builder check, 2026-11-21):**

1. `engine_status` is **per feature, never per stage**. It certifies that one
   specific id exists in the build today, not that a whole stage is playable.
   Implemented upgrade ids: `surface_grip`, `crawl`, `absorption_channel`,
   `spike_ring`, `spike_burst`, `energy_pool`. Implemented boss ids: `rot_bloom`.
   Implemented obstacle kinds: `static_slab` and `gate` (the M5 evolution gate).
   Every other id is `planned` and must name `fallback_until_implemented`,
   including planned obstacles. `stage_status` is derived from features:
   `implemented` only when upgrade and boss are both implemented;
   `partial` when only some are; `planned` when none are. This makes stage 03
   the only fully implemented stage, while stages 01/02/04 keep their real M1/M2/M4
   upgrades and honestly planned bosses.
2. Rectangles use a documented **design-only coordinate space of 1920×1080 world
   units**, matching the existing rooms' scale. They are illustrative layouts,
   not extracted build constants; stage 03 echoes M5's gate/pillar arrangement
   conceptually. `SCHEMA.md` states this so no coordinate is read as a factual
   claim about `room_builder.gd`.

### Constraints baked into the JSON

- **Obstacles must exist.** Checker rejects a map with fewer than two solid
  slabs or with a zero/negative rectangle.
- **Resource honesty.** Every `resources.model` is `single_nutrition`. Named
  future resources (calcium, protein, genetic material) may appear only as
  `future_resource` with status `Open`; the checker rejects any second meter.
- **Boss identity.** `boss.kind` must be `hostile_organism`. The mother is a
  guide-only environmental presence (`narrative.mother_role: guide_only` or
  `absent`); a boss may never be the mother or her body framed as an enemy.
- **No permanent branch choices.** Each upgrade is an additive unlock owned
  forever. Every map states `upgrade.softlock_fallback`; stage 07's veil is
  optional and stage 08's final boss accepts any prior offensive unlock.
- **Engine honesty.** Each obstacle, upgrade and boss carries its own
  `engine_status`. `implemented` is allowed only for an id in the checker's
  explicit build whitelist; everything else is `planned` and must name a
  `fallback_until_implemented`. `stage_status` is derived, never asserted by hand.
- **Progression safety.** Boss gates require only an upgrade from this or an
  earlier stage; energy always regenerates, so no resource can be permanently
  exhausted. Defeat returns to the shelter, resets the boss, and preserves
  evolution/nutrition — the M5 policy.

### Status of the result

The 8-stage structure is **Proposed**, because the repo still lists 7–9 stages
as Proposed/Risk and the full world as out of scope. Stage 01–03 / M1–M5 content
is **implemented but its numeric design values remain Proposed**. Stages 04–08
are **Proposed** design only. No art direction is Approved; all names are
working names. The checker and review report are evidence, not decisions — only
the owner can promote this into production scope.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Deliver design JSON + validator, no Godot loader | Confirmed | Owner chose "Design + validator" on 2026-11-21 |
| Eight stages, each with obstacles, upgrade and boss | Proposed | Owner-requested design exploration; production scope still Open |
| Stage chain as tabled above | Proposed | Agent proposal from §7/§5/§4 and M1–M5 patterns |
| Mother never a boss; guide-only presence | Confirmed | `GAME_DESIGN_FOUNDATION.md` §6/§11, `DEVELOPMENT_PLAN.md` §1 |
| Single `nutrition` meter in every map | Proposed | §4 validation requirement; five meters explicitly deferred |
| Upgrades additive, no permanent branch choice | Proposed | Protects against the §5/§10 softlock risk |
| `engine_status` is per feature; `stage_status` derived | Proposed | Builder call from the builder check; prevents a stage with a planned boss being certified implemented |
| 1920×1080 design-only coordinate space | Proposed | Builder call; illustrative layout, not extracted build constants |
| Final boss/ending emotional beat | Open | Owner playtest and narrative review |
| Actual production of stages 04–08 | Open | Out of scope until the vertical slice gate passes |

## Non-goals

- No Godot loader, scenes, scripts, animation, audio or new resource types.
- No changes to `game/` or to any existing scene, script or test.
- No editing of `docs/MILESTONES.md`, `docs/BACKLOG.md` or official design
  decisions; this design does not promote a proposal to a requirement.
- No claim that eight bosses are buildable within the current scope.
- No Muse/art direction approval.

## Anti-goals

- A map set that looks complete but cannot be loaded or played — the JSON must
  say plainly that it is a design artifact.
- Eight reskins of the M1/M2 room with numbered bosses and no distinct
  traversal or combat idea.
- A boss that is the mother, or a required fight that a previously chosen build
  can make unbeatable.
- A validator that always passes — it must fail on missing obstacles, missing
  upgrades/bosses, broken chain links and dishonest engine status.

## Progression safety

No mutually exclusive permanent choice is introduced, so the set cannot create
a bad build. Each stage's gate depends on an upgrade from this or an earlier
stage; stage 03's Rot Bloom reuses the implemented evolution gate, so an
unevolved player sees a dormant boss and a HUD prompt rather than an unwinnable
fight. Energy is never a gate: it regenerates at 1/s with no pickups, and stage
07's optional veil is not required to beat its boss. Stage 08's last boss accepts
`spike_burst` if a later body weapon has not been earned. On defeat, the shelter
restores health and energy and resets only the boss. Fallback if any designed
fight proves unbeatable: widen a weak window or lower boss health — never add a
mandatory new evolution that would break earlier stages.

## Acceptance

- [ ] `docs/maps/map01.json` … `map08.json` exist and parse as JSON.
- [ ] `pwsh -File tools/check_maps.ps1` prints `MAP CHECK PASSED` with 8 maps
      checked, and exits 0.
- [ ] The checker is proven to fail: a temporary broken copy (missing obstacle
      or broken chain link) produces a named failure and exit 1; the real files
      are restored afterwards.
- [ ] `docs/maps/REVIEW.md` records the observed checker output plus a per-map
      review of obstacle/upgrade/boss/plan alignment and softlock safety.
- [ ] `pwsh -File harness/scripts/check.ps1` still reports `HARNESS CHECK PASSED`.
- [ ] Human (owner): can read the eight-map chain and say where it drifts from
      the repo plan; this review is not a milestone PASS.

## Risks

| Risk | Mitigation |
|---|---|
| Eight bosses contradict "multiple bosses out of scope" | Marked Proposed design exploration; no code is written; owner decides production |
| Map JSON mistaken for a working level | `SCHEMA.md` and every map declare `artifact_type: design_only` and `engine_status` |
| Designed abilities (dash, glide, combos) stay unimplemented | `engine_status: planned` + `fallback_until_implemented` on every such map |
| Resource economy silently grows to five meters | Checker enforces `single_nutrition`; extra names are Open-flavoured only |
| Mother accidentally framed as antagonist | Checker rejects boss kind `mother`/`parent`; review inspects `narrative.mother_role` |
| Scope pressure to start building all eight | Non-goals and the vertical-slice gate stay explicit |

## Open questions

- Does the owner want these eight maps promoted to production scope, or kept as
  a design reference until Phase 3's vertical slice passes? — owner; changes
  whether any loader/scene work is scheduled.
- Are the working names and boss concepts acceptable starting points? — owner;
  renaming is data-only and needs no code.
- Should the review report later be regenerated from inside `tools/verify.ps1`?
  — builder decision when Phase 4 starts; not needed for this design.
