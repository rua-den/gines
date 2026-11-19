# M2 — Absorption & Survival (design)

**Date:** 2026-11-19
**Status:** Proposed by agent under explicit "continue" instruction; owner may veto any part.
**Scope:** `BACKLOG.md` Milestone 2 — one resource, one absorbable organism, absorption
feedback, one hostile organism, damage/survival, restart. Built as a new scene so the
verified M1 scene and its evidence stay untouched.

## Intent

The prototype must answer one question: **is feeding a decision?** Movement is already in
place. M2 adds the first loop that can be lost — food that takes time to take, and a
predator that punishes taking it at the wrong moment.

## The decision that shapes everything

How does absorption happen? Three real options:

**A. Contact snatch** — overlap absorbs instantly, no input.
Cheapest, and it reads immediately. But the environment is fluid with no gravity, so
"swim into it" makes food unavoidable and free: there is no moment where the player
chooses anything. Rejected: it removes the verb.

**B. Grip-feed** — `grip` onto the organism and hold on.
Strongest identity (the body attaches to what it eats) and reuses an existing verb, but
`grip` currently only works against static collision surfaces through
`is_on_floor/wall/ceiling`. Free-floating food would need grip extended to movable
targets — new physics, new failure modes, and 90 px/s on a drifting target is likely to
feel bad. Rejected for M2; worth revisiting once organisms are anchored.

**C. Channel-hold `interact`** — stay within range of a mote with `interact` held for
0.75 s. Leaving range, releasing, or taking a hit resets the channel.
Uses the `interact` action that is already bound in `project.godot` and currently read by
nothing, so no input-map change. Commitment comes from **time in range plus a speed
penalty while feeding** (swim cap drops 260 → 90), which makes feeding a gamble near a
predator. Testable headlessly by counting physics frames. **Chosen.**

## Goals

- Feeding is a visible, interruptible act, not a collision.
- A predator makes feeding risky; escaping is always possible (predator chase speed
  165 px/s < player swim 260 px/s).
- Damage, defeat and retry are testable without restarting the application.
- Every mechanic ships with a headless regression check, per the M1 close-out standard.

## Non-goals

- Multiple resources, inventory, evolution (M3), save/load.
- Audio (no audio assets yet) — feedback is visual + HUD only, stated plainly so no one
  assumes sound exists.
- Authored art: shapes and gradient textures, same as M1.
- Dropping resources on death (foundation §9 says "some resources are dropped"; prototype
  keeps nutrition across a retry — simplification, recorded here).

## How it works

**Resource model.** One value, `nutrition: float` on the player, plus a
`nutrition_gained(amount)` signal. No resource dictionary, no manager node, no meter
beyond one HUD line. A mote is worth 10.

**Absorbable** (`scripts/absorbable.gd`, group `absorbable`): a drifting glowing mote with
`nutrition_value`, `progress`, `consumed`. `channel(delta)` advances its progress,
`cancel_channel()` zeroes it, `consume()` plays a shrink-and-fade burst and marks it
consumed. Selecting targets by group + distance avoids introducing collision layers for
what is currently four nodes.

**Player additions.**
- `interact` held → nearest unconsumed absorbable within 90 px becomes the channel target.
- Channel completes at 0.75 s; nutrition increases once per mote.
- Feeding drag: while channeling, the swim speed cap is 90 px/s.
- `take_damage(amount, from_pos)`: 3 health, 1 s invulnerability, knockback, channel cancel,
  visual flicker; at 0 → `dead`, `died` signal, physics input ignored.
- `revive()`: full health, 1 s grace, channel cleared.

**Predator** (`scripts/predator.gd`): patrols horizontally, chases when the player is
within 420 px, deals 1 damage on contact closer than 66 px, turns at walls, idles when the
player is dead. Damage is distance-based rather than physical collision, so the player is
never wedged into geometry by the enemy.

**Restart.** On `died`, an overlay appears; `interact` (fresh press) calls `revive()` and
returns the player to the start position. Nutrition and consumed motes persist — retrying
must not require restarting the application.

**Scene.** `scenes/prototype.tscn` + `scripts/prototype.gd`, self-contained: its own calm
background, the same 1920×1080 five-slab room geometry, four motes, one predator, camera,
HUD (health pips, nutrition, hint). The room drawing helpers are duplicated from
`movement_test.gd` rather than extracted; with two scenes a shared module is not yet
earning its cost, and M1's verified scene stays untouched. Extract when a third scene
appears.

## Verification

- `tests/absorption_check.gd`: completes in range, resets on release, resets on leaving
  range, cannot double-absorb, damage cancels the channel.
- `tests/survival_check.gd`: contact damage, invulnerability window, expiry, death, revive,
  chase-vs-patrol behaviour.
- `--m2-demo` autopilot in `prototype.gd` captures absorb / hit / retry screenshots and
  exits non-zero when its criteria fail, matching M1's verdict contract.
- `tools/verify.ps1` gains both headless checks and the M2 demo.

## Risks

- Feeding drag could feel like a bug rather than a cost; the owner playtest decides.
- Distance-based damage can look like a hit that did not visually connect at 66 px against
  a 55 px player radius — tune after playtest, do not assume.
- M1's human verdict is still unrecorded; M2 does not wait for it, but a REVISE on movement
  would change the numbers above, not the structure.
