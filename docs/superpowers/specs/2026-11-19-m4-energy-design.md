# M4 — Energy for the Spike Burst (design)

**Date:** 2026-11-19

**Status:** Proposed by agent for owner review; no values or behavior are confirmed.

**Scope:** Add a small energy loop to the existing evolved spike burst and validate it against the existing predator.

## Intent

M3 proved that the first evolution grants a usable attack. M4 should test the next Phase 2 question: **does spending and recovering energy make using that ability more interesting?** This is a focused balance prototype, not a boss milestone.

## Approaches

1. **Add energy and a boss together.** Completes more of Phase 2 at once, but couples two substantial balance questions.
2. **Add energy to the existing spike burst and test against the predator (recommended).** Reuses the current ability, enemy and room; isolates whether energy adds a meaningful decision.
3. **Build a boss around the cooldown-only burst and add energy later.** Reaches a boss sooner, but does not test the Phase 2 energy loop.

## Proposed design

- Keep `spike_burst` as the one biological special ability; add no second attack.
- Give the evolved player a temporary energy pool: proposed maximum 3, cost 1 per burst, passive regeneration at 1 energy per second.
- Show current energy in the existing HUD. Keep the existing cooldown as an input guard; energy should be the meaningful limit on repeated use.
- Start with full energy on a fresh run and after retry. Do not save energy; retain the existing saved evolution and nutrition state.
- Energy never gates movement, absorption, evolution, or required progress. It only limits optional burst use, and regenerates without requiring a new resource source.
- Use the existing predator and prototype room to judge whether players can understand and manage energy. Defer a boss encounter to a later milestone.

All numeric values are **Proposed** and should be tuned during playtest. No energy is needed before evolution, and an unavailable burst must not damage or consume energy.

## Goals and non-goals

**Goals:** one small, readable energy resource; a visible cost and recovery loop; verify attack affordability, denial at zero energy, and recovery.

**Non-goals:** boss, second ability, energy pickups, multiple resource types, save-format expansion, final HUD/art/audio, or changes to movement and absorption.

## Constraints

- Godot 4.7.2; use the existing player, HUD, predator and test patterns.
- Keep the change small and reversible; do not extract shared systems for one prototype scene.
- Preserve the rule that evolution choices cannot softlock required progress.

## Acceptance

- After evolution, HUD energy is visible and changes when the burst is used and recharges.
- A burst spends exactly its cost once; insufficient energy rejects the attack without side effects.
- Energy recharges to, but never above, its maximum.
- Before evolution, the burst remains unavailable and energy cannot be spent.
- Energy starts full after retry/relaunch; evolved state and nutrition keep their existing persistence behavior.
- The owner can complete a short encounter without instructions and judge whether energy adds a useful decision.

## Open

- Are the proposed capacity, cost and regeneration rate a good starting feel?
- Should energy regenerate continuously, as proposed, or only after a delay following an attack?
- Does the energy indicator read clearly in the current compact HUD?
