# M3 — First Evolution (design)

**Date:** 2026-11-19
**Status:** Proposed by agent under the owner's standing "keep going, invent what is
missing" instruction. Nothing here is owner-approved; change numbers freely.
**Scope:** `BACKLOG.md` Milestone 3 — one requirement, one site, one visible
transformation, one ability, feedback, and persistence.

## Intent

M2 answered "is feeding a decision?". M3 must answer: **does the absorbed resource
turn into something the player wants, and does that change the game?**

The milestone only earns its place if the transformation is *felt* — visible on the
body, immediately usable, and permanent enough to survive a restart. A menu that adds
+1 damage does not count.

## Decisions

**1. Cost and repeatability — 30 nutrition, once.**
Four motes at 10 plus the predator's 15 reward is 55 available nutrition; 30 leaves a
runt of resource for M4 rather than zeroing the bar and implying a bigger economy than
exists. One evolution, no choice: a choice needs two viable options, and there is only
one body part so far. A second evolution site is M4+ work.

**2. Site — a golden alcove at (1720, 420), activated with `interact` in range.**
Far right, past the predator's patrol (x 1000–1520), so reaching it is the first
"traversal past a threat" beat. The rule lives in `player.can_evolve()`; the zone owns
only a radius and a look. One place to test, one place to change.

**3. Body part — a ring of fourteen golden spikes (`player_visual.set_evolved`).**
Visible at a glance, animated with a slow breath, and describable in one sentence. No
new art pipeline: `Polygon2D` triangles around the existing body.

**4. Ability — `spike_burst`, radius 130 px, 1 damage, 0.8 s cooldown, `attack` (J,
gamepad west→button 3).**
Short-range radial burst, not a projectile: it rewards closing distance, which is the
same risk the predator already punishes. 130 px is slightly inside the predator's
66 px bite plus a body radius, so the trade is real but winnable.

**5. The predator becomes killable — 2 HP, 15 nutrition on death, one `killed` signal.**
Two bursts confirm the ability did it. The reward pays for roughly half of a future
evolution without trivialising the economy.

**6. Persistence — `SaveState`, one `ConfigFile` section at `user://genesis_save.cfg`.**
Stores `evolved` and `nutrition` only. No schema version, no autoload: the prototype
needs exactly one fact to survive a restart. Demo runs never read or write the player's
save; `--fresh-save` clears it for a clean comparison.

**7. Transformation feedback — grace window plus shockwave (agent-proposed).**
Observed in the first demo runs: the predator follows the player into the alcove, so
the payoff moment was a point-blank brawl and the player lost two hearts before the
first burst. Evolving now grants 1.5 s of grace and pushes organisms out to 120 px,
where they reel for 0.8 s. This is a feel decision, not a balance one — it makes the
transformation a beat. It is also the easiest thing here to delete if the owner
disagrees.

## Non-goals

- Evolution choices, multiple body parts, ability upgrades.
- Saving position, consumed motes or the predator's state — only progress.
- Audio; feedback stays visual + HUD, as in M1/M2.
- New enemy behaviour. The predator is unchanged except that it can now die.

## What "done" means

- `--m3-demo` exits 0 with four named captures (`requirement`, `evolve`, `burst`,
  `kill`), and exits 1 if any of them, the evolution, the kill, the economy or the room
  bounds is wrong.
- `tests/evolution_check.gd` covers the contract headlessly, including a second scene
  run loading the evolved body from disk.
- `tests/m3_verdict_check.gd` proves the verdict itself can fail.
- `tools/verify.ps1` includes all of the above; 14 checks, all passing.

## Open questions for the owner

- Is the burst readable as *caused by the spikes* without instructions?
- Does the grace/shockwave feel like a payoff or like losing control of the body?
- Is one evolution enough for the vertical slice, or does the slice need a second site
  to show that the body changes more than once?
