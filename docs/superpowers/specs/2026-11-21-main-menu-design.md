# Main Menu — Design Brief

**Date:** 2026-11-21
**Author:** orchestrator (owner previously delegated decisions with "tự quyết")
**Status:** Proposed. Layout is procedural UI, not approved art direction.
**Milestone / phase:** Phase 3/4 player-facing entry point.

## Problem

`game/project.godot:15` opens `test_scene.tscn` (the M0 scaling test), and no
menu code exists. A player has no way to start a chosen map or the region slice
from the application; they must launch a specific scene from the command line.
This blocks even a minimal "feel like a real game" experience.

In player terms: launch the game → see a title → choose New Game / Continue /
Map Select → pick a stage → press Start → play.

## Current state

- 14 scenes exist: test/movement/prototype/boss, region slice, map runner,
  map02..map08. All have headless tests; verifier 42 checks, checker 540, harness 65.
- Input actions in `project.godot`: `move_up/down/left/right`, `interact`,
  `grip`, `attack`, `pause`. No new input action needed.
- UI is procedural (Labels/Panels, translucent dark frames + accent color) in
  existing scenes (`prototype.gd`, `boss_fight.gd`, `map_stage.gd`). No font or
  texture assets exist; no audio.
- Save: `user://genesis_save.cfg` holds only `evolved`, `nutrition`.
- Decision rules: `harness/project.md` §§Decision rules, Scope guard.

## Approaches considered

| # | Approach | Verdict |
|---|---|---|
| 1 | Change `project.godot` main scene to an existing prototype | Rejected — not a menu; no choice flow |
| 2 | New procedural `MainMenu` scene with panels + tests, set as main scene | **Chosen** |
| 3 | Build an asset-based cinematic menu | Rejected — no approved art/audio; high cost |

**Chosen: approach 2.** Reuse the existing procedural UI conventions and input
actions; no art, audio or animation.

## Design

Panels, one visible at a time:
1. **Title** — game name + tagline (provisional), `interact` → Main.
2. **Main** — New Game, Continue, Map Select, Quit. `move_up/down` changes
   selection, `interact` activates, `attack`/`pause` goes back to Title from Main.
   - *New Game* clears the save, then opens Map Select.
   - *Continue* loads the save and starts the Region Slice (`region_slice.tscn`).
     If no save exists, show a short "no progress" line and stay on Main.
   - *Map Select* opens the stage list.
   - *Quit* quits the tree.
3. **Map Select** — entries: Region Slice, map01 … map08. Each line shows the
   stage name and an honest status marker: `code exists`, `placeholder`, or
   `proposed placeholder`. `move_up/down` navigates, `interact` starts the
   chosen scene via `get_tree().change_scene_to_file(path)`, `attack`/`pause`
   returns to Main.

The scene prints `[MENU] READY` in `_ready()` and exposes a pure
`evaluate_menu(facts)` returning named failures for headless assertions.
`project.godot` main scene becomes `res://scenes/main_menu.tscn`.

No new save field, no new input action, no art/audio. `interact` is E/Space,
`move_up/down` are W/S and arrows; gamepad already mapped.

## Decisions

| Decision | Status | Note |
|---|---|---|
| Add a procedural main menu and make it the default scene | Proposed | Fills the missing entry point; no approved UI art |
| Menu uses existing input actions only | Proposed | No input-map churn |
| Placeholder stages stay labelled Proposed in Map Select | Proposed | No promotion of design artifacts |
| Continue starts the Region Slice | Proposed | Only continuous loop available today |
| Art, audio, localization of menu text | Open | No approved direction; text is English-first |

## Non-goals

- No settings/options panel, credits, controller remapping or save-slot UI.
- No new art/audio/font, no change to gameplay scenes or map data.
- No claim that this is a final UI or an approved visual direction.

## Anti-goals

- A menu that starts a scene without a visible selection/status.
- A "Continue" that silently starts with no save.
- Breaking the 42 verification checks.

## Progression safety

New Game clears the save — this is a destructive player action, so the menu must
show confirmation before clearing (two-step: select New Game, press `interact`
once to show "Erase progress? interact again", second `interact` clears and
continues; `attack`/`pause` cancels). This protects the existing save workflow.
No other permanent choice is introduced.

## Acceptance

- [ ] `game/scenes/main_menu.tscn` + `game/scripts/main_menu.gd` exist; headless
      smoke prints `[MENU] READY`.
- [ ] `project.godot` main scene points to the menu; all old scenes still load.
- [ ] `game/tests/menu_check.gd` asserts: initial panel Title; Title→Main on
      interact; Main navigation wraps; New Game requires confirmation and only
      then clears the save; Continue with no save stays on Main; Map Select
      lists all 10 entries with honest statuses; selecting entry returns the
      correct `res://scenes/...` path; back navigation works; Quit is callable;
      a named negative fixture fails.
- [ ] Verifier gains smoke + regression lines (42 → 44); checker 540 unchanged;
      harness 65 unchanged.
- [ ] No unobserved PASS, no art approval, no milestone decision.

## Risks

| Risk | Mitigation |
|---|---|
| Changing the main scene breaks existing smoke commands | Verifier smoke commands pass explicit scene paths; run full suite |
| New Game erases progress accidentally | Two-step confirmation; cancel supported |
| Menu text implies approved art | Procedural labels; status Open in docs |

## Open questions

- Should Continue resume the last map instead of the Region Slice? — owner;
  changes one line of scene routing.
