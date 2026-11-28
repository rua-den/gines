# GENESIS generated art skin

**Status: Proposed / owner visual and audio review Open.** Replace the displayed
asset suite with original generated art, not room logic, input, numerical
combat parameters, collision, node lifecycles, save state, fonts, or story.
Assets Creator Rust is the generator. The generated asset bundle lives at
`game/assets/genesis/`; it does not grant approval to CHR-001 or a birth scene.
The procedural presentation remains a fallback for a sparse source checkout.

| Existing visual class | Authored resource and behavior |
|---|---|
| Protagonist body, rim, cilia, nucleus, evolved spikes | `player_base.png` and `player_evolved.png`, reused by the common player scene. Both present or both use the procedural fallback. Cilia are baked into the authored silhouette. Existing directional squash/rotation remains; no new movement states. |
| Common predator, Rot Bloom, final Convergence | `predator.png`, `bloom.png`, `final_boss.png`; actual creature classes select their own. Pulse rate, exposed-state opacity, and defeat fade remain. Planned fallback bosses still use their actual runtime types. |
| Nutrient, evolution alcove | `mote.png`, `evolution_zone.png`; actual motive/channel motion, consumption, and alcove used/readiness behavior remain. |
| Terrain, gates, hazards | Repeat `stone.png`, `growth.png`, `gate.png` and `hazard.png` on the existing room polygons. Solid geometry and existing high-contrast top-edge/UI indicators remain. |
| Checkpoint and completion readability | `checkpoint.png` and `goal.png` only when present; attached to map rebuild ownership and to the existing completion Label, respectively. No new saved points or completion logic. |
| Burst attack feedback | `spike_burst.tres` plus generated strip; append the 8-frame, 24 FPS non-looping glow to accepted attacks. The code-drawn ring remains as the semantic reach indicator, not as authored decorative imagery. |
| Backgrounds | `world_backdrop.png`, optional `world_map01.png` … `world_map09.png`, and `menu_backdrop.png`; applied behind gameplay via CanvasLayer, noninteractive and scaled to cover. |
| Main/HUD/pause/campaign panel surfaces | `ui_panel.png` optionally paints a 9-slice surface, not fonts/copy/layout or selection. Semantic text and its colors remain native. |

Remaining outside this first surface: the milestone-only M0 test mock canvas,
application icon (separate Godot project setting), original archived evidence
screenshots, and creative concept files. Do not overwrite evidence, measure
approved art or gameplay feel from renderer tests, or claim a new song/region/
cinematic. Background styling, primary silhouettes, contrast, and optional
markers/panels still require visual inspection on a real renderer.

## Verification

- Source fallback: `godot --headless --path game --import` then run
  `godot --headless --audio-driver Dummy --path game --script res://tests/genesis_art_check.gd`.
- Complete bundle: same test with trailing `-- --require-art` to fail if the
  art is unavailable, verify texture swaps/bindings, import non-looping VFX,
  compare collision dimensions and check actual map actors and backdrops.
- Re-run the normal campaign, boss, energy and map verifier; no milestone PASS
  is granted by the above.
