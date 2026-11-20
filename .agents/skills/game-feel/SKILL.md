---
name: Game Feel
description: Diagnose and tune how the game feels — movement, camera, hit feedback, timing, juice and readability. Use when something feels floaty, sluggish, weightless, unfair or unresponsive, or when tuning proposed balance values in playtest.
---

# Game Feel

"Feels wrong" is a real problem description. This skill turns it into measured
inputs, a small number of candidate changes, and playtest evidence.

## First

1. Read `harness/project.md` for the current milestone and rules. If it is
   missing, ask for the project facts.
2. Read the relevant controller/feedback code and the latest design or
   milestone notes. Find the constants that already exist before adding new
   ones.
3. Load the `test-driven-development` skill if the tuning changes code paths
   (not just constant values).

## Workflow

1. **Name the felt problem in player terms.** "The cell stops too abruptly
   after a dash", "the burst has no impact", "the camera loses the player in the
   alcove". Not "increase friction".
2. **Name the measurable inputs.** Acceleration, max speed, drag/friction,
   camera smoothing and deadzone, input buffer/coyote time, telegraph length,
   hitstop, knockback, flash/duration. Write down the current values.
3. **Propose 2–3 candidate sets.** For each: what changes, what the player
   should feel, and the risk (slippery, unresponsive, nauseating camera,
   unreadable). Recommend one; say why the others don't fit.
4. **Test with a stated criterion.** Write the criterion before playing:
   "the player can stop within half a body length", "the hit reads without
   watching the health bar". Record the result with
   `harness/templates/playtest-report.md`.
5. **Change one axis at a time.** Re-run the relevant automated check after
   each code change; re-play the scenario after each feel change.
6. **Record values and status.** Log before/after numbers and the evidence
   path. Tuned values are **Proposed** until the owner confirms them.

## Must not

- Tune by intuition and report it as verified feel.
- Change several axes at once so the cause of a regression is unknown.
- Let feel changes gate required progression (jump height, dash distance,
  interaction range that a mandatory route depends on).
- Use feel as a reason to expand scope; if the fix needs a new system, stop
  and use `game-design`.
