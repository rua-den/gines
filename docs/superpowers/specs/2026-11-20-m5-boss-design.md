# M5 — The First Boss Encounter (design)

**Date:** 2026-11-20
**Author:** agent (under the owner's standing "keep going and invent what is missing" instruction)
**Status:** Proposed — no decision below is Confirmed by the owner.
**Milestone / phase:** Phase 2, Milestone 5
**Template:** `harness/templates/design-brief.md`

## Problem

By the end of M4 the player can swim, crawl, grip, absorb nutrition, evolve once,
and spend/recover energy on a radial spike burst. What is missing is a moment
that requires all of it at once. Today the strongest interaction is a two-hit
predator that can be outrun; there is no encounter where "I used to be fragile,
now I am capable" is *felt* rather than stated by a HUD flag. Phase 2's exit
criteria explicitly ask for that progression feeling and for combat to interact
with evolution. Without a climax, Phase 2 cannot honestly close and Phase 3
(vertical slice) has no proof that the core loop peaks.

In player terms: the player should meet one threat they cannot simply swim past,
learn its rhythm, and beat it by using the body they grew — not by finding a
better menu number.

## Current state

- Phase 2 items done: resource collection (M2), evolution requirement + zone
  (M3), body transformation (M3), offensive body part = `spike_burst` (M3),
  biological ability (M3), energy management (M4), evolution feedback (M3).
  The **only** unimplemented Phase 2 item is "one boss encounter"
  (`docs/DEVELOPMENT_PLAN.md` §3, `docs/BACKLOG.md`). "Multiple bosses" is
  explicitly out of scope, so one boss is in scope.
- Build: `game/scripts/player.gd` (PlayerController, 3 health, burst with
  `MAX_ENERGY` 3 / cost 1 / regen 1/s, 0.8 s cooldown, 130 px reach),
  `game/scripts/predator.gd` (2 health, telegraphed chase/contact, `stagger`
  reuse), `game/scripts/evolution_zone.gd`, `game/scripts/burst_ring.gd`,
  `game/scripts/save_state.gd` (`evolved` + `nutrition` only).
- `game/scripts/prototype.gd` is already the largest script and duplicates room
  drawing from `movement_test.gd`; `docs/MILESTONES.md` (M3 known limitations)
  names it as the first extraction candidate once a third scene needs the room.
- No audio assets exist; visual feedback is procedural gradients, not frame
  animation. Both are stated, not implied.
- Decision vocabulary and gate rules: `harness/project.md` §"Decision rules",
  `docs/DEVELOPMENT_PLAN.md` §9.

## Approaches considered

| # | Approach | Player value | Solo cost | Rules out | Verdict |
|---|---|---|---|---|---|
| 1 | Add the boss as another mode inside `prototype.tscn` | Fastest to ship; reuses room | Lowest, but inflates the largest script and mixes three scenes' concerns | Clean isolation and a dedicated demo | Rejected |
| 2 | Dedicated boss scene reusing player/HUD, with a small shared room builder | Isolated, headlessly testable fight; room duplication finally resolved | Modest: one scene + two scripts + one helper + tests | A second boss / a full region (out of scope anyway) | **Chosen** |
| 3 | Skip the boss; jump to Phase 3 with a second evolution branch | More content sooner | High (new progression + art) | Closing Phase 2; no proof the loop peaks | Rejected |

**Chosen: approach 2.** The boss is the last Phase 2 item, so it should be the
smallest isolated change that can be observed. A dedicated scene keeps
`prototype.gd` from growing and gives the fight its own demo and failure gate.
Extracting the room is justified now because the boss scene is the third consumer
of the same geometry.

## Design

**Working name:** the Rot Bloom (a parasitic organism rooted in the far wall;
this is a working name, not an approved art direction).

**Loop:** approach corridor → telegraphed attack → dodge or grip → 1.5 s exposed
core → one or two bursts (spending energy) → repeat → victory opens the route
deeper. The existing predator stays in the approach corridor as the warm-up.

**Proposed values** (all tunable, none Confirmed):

| Value | Proposed | Reason |
|---|---|---|
| Boss health | 6 | Three accepted bursts with no waste; energy (max 3) forces at least one regen pause |
| Weak-window duration | 1.5 s | Time for 1–2 bursts inside the 0.8 s cooldown; rewards being in position |
| Attack cycle | two attacks, alternating | Lash (horizontal sweep, dodge above/below or grip) and Spore ring (radial with one gap, dodge through gap or grip out of range) |
| Attack telegraph | 0.6 s | Readable without instructions; matches M2/M3 "legible at a glance" pattern |
| Attack damage | 1 | Player has 3 health; two mistakes are survivable |
| Stagger after weak window | boss inert during exposure | Mirrors `predator.stagger`; makes the window safe to learn |
| Boss body damage | only during weak window | Forces timing; prevents holding burst to win |

**Arena and progression:**

- Boss sits past the golden alcove. A gate opens only for an evolved player; an
  unevolved player sees a dormant bloom and a HUD line "evolve first" instead of
  an unwinnable fight. This is the explicit softlock guard.
- A biological shelter/checkpoint just before the arena is the retry point. On
  defeat: boss health resets, energy refills, evolution + nutrition persist,
  consumed motes stay consumed — same policy as M2/M3 retry.
- The fight never gates movement, absorption, evolution or required progress;
  energy regenerates passively, so no resource can run out permanently.

**Feedback:** existing `burst_ring.gd` for hits; bloom pulsing during telegraph,
dimming during the weak window, and fading on defeat; HUD boss health line and a
"NOW" prompt during exposure. No audio (no assets). Visual is a procedural
gradient like the predator — no frame-by-frame animation in this prototype.

## Decisions

| Decision | Status | Note |
|---|---|---|
| M5 scope = one boss encounter | Proposed | Derived from the single open Phase 2 item; owner's standing "invent what is missing" instruction |
| Boss is a new hostile organism, not the mother | Proposed | Foundation §6/§11: mother is nurturing/protective, never the boss |
| Health 6, weak window 1.5 s, two telegraphed attacks | Proposed | Tune during playtest; not a design reversal |
| Burst damages the boss only during the weak window | Proposed | Makes evolution a timing skill, not a damage number |
| Dedicated boss scene + small room-builder extraction | Proposed | Third consumer of the room justifies extraction |
| Retry at shelter; evolution + nutrition persist; boss resets | Proposed | Consistent with M2 retry and M3 save policy |
| Evolution gate before the arena | Proposed | Progression-safety requirement, not a difficulty gate |
| Procedural visual, no audio | Proposed | Prototype constraint; audio/animation deferred |
| Fight feels like a payoff of evolution | Open | Owner playtest only |
| Final difficulty values | Open | Owner playtest + tuning |
| Second boss / second evolution / full region | Open (deferred) | Out of scope for Phase 2 |

## Non-goals

- A second boss, a second evolution branch, or a full world region.
- New resource types or changes to the save format.
- Frame-by-frame boss animation, voice, music or sound effects.
- Final HUD/art polish, New Game+, multiple endings.
- Changing movement, absorption or the existing predator's behavior.

## Anti-goals

- A boss that can be beaten by holding `J` without reading a telegraph.
- A boss that is impossible without a future evolution (softlock).
- A boss that kills in two untelegraphed hits and turns the room into a retry loop.
- Adding "one more enemy" that does not test the evolved body specifically.

## Progression safety

No permanent choice is introduced in M5, so M5 cannot create a bad build. The
two real softlock risks are (a) reaching the boss unevolved and (b) arriving with
zero energy. Mitigations: (a) the gate stays closed and the bloom is dormant
until `player.evolved` is true — a "return later" signal, not a fight;
(b) energy regenerates at 1/s with no external source, so waiting always
restores it. On defeat the shelter retry restores health and energy while
keeping earned progress. Required content (M0–M4) is unchanged and remains
beatable. Fallback path: if the fight proves unbeatable in testing, reduce boss
health or lengthen the weak window — never add a mandatory second evolution.

## Acceptance

Automated (headless, Godot 4.7.2, `_console.exe` on Windows):

- [ ] Boss takes damage only during the weak window; a burst outside it deals
      no damage to the boss. Energy is still spent, exactly as for any fired
      burst that misses — `spike_burst()` spends before hit resolution.
- [ ] A burst inside the window spends exactly one energy and one boss health;
      starved/cooldown bursts have no side effects. A fired burst outside the
      window spends energy but deals no boss damage.
- [ ] Boss health reaching zero emits `defeated` exactly once and stops all
      damage/movement.
- [ ] Boss damages the player only during its attack phase, never while
      staggered/exposed/defeated.
- [ ] The gate blocks an unevolved player and opens after evolution, end-to-end
      in a real scene run.
- [ ] Shelter retry resets boss health and refills energy while preserving
      `evolved` and `nutrition`.
- [ ] `tests/boss_check.gd` covers the above and is added to `tools/verify.ps1`;
      `--m5-demo` captures named `approach`, `telegraph`, `weak-window` and
      `victory` shots and exits 1 on any failed criterion.
- [ ] `harness/scripts/check.ps1` still reports `HARNESS CHECK PASSED`.

Human (owner):

- [ ] The owner can beat the boss without reading the README and can say the
      win came from using the evolved body, not from tanking hits.
- [ ] The telegraph and weak window are legible; waiting for energy reads as a
      decision rather than downtime.

## Risks

| Risk | Mitigation |
|---|---|
| 3 health plus 130 px burst reach makes the window too tight | 0.6 s telegraph, 1.5 s window, boss inert while exposed; tune after playtest |
| Room-builder extraction touches M0–M3 scenes | Keep it to drawing helpers only; run the full suite after extraction |
| Boss visual reads as another predator | Distinct silhouette (anchored bloom vs mobile sphere), larger scale, different palette |
| "Energy bar implies an economy" concern from M4 | No pickups, no second ability; boss only uses the existing pool |
| Scope creep toward a full region | Explicit non-goals; vertical slice is Phase 3 |

## Open questions

- Does the owner want the boss to lean more toward mechanical challenge or
  toward the emotional "protect the journey" beat? — owner; changes telegraph
  length, damage and whether the bloom speaks through environment rather than
  HP alone.
- Are the proposed health, window and telegraph values good starting feel? —
  owner playtest; tuning only.
- Should extraction include the HUD build as well as room drawing? — builder;
  a sensible call, settled in the plan unless it changes scope.
