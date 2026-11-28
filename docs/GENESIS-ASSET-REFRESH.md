# Genesis asset refresh

Scope: replace the visible placeholder artwork in the shipped campaign and playable
prototype scenes with a coherent generated Genesis theme, and add original short cues
to accepted gameplay events. Preserve level geometry, collision shapes, hit radii,
damage, timing, navigation/input, save format, text and official campaign ordering.
Keep combat telegraphs, the burst range ring and other informational overlays readable;
those overlays are gameplay UI, not decorative art. Retain a fallback for incomplete
development checkouts; the packaged game must exercise generated assets by default.

The direction follows DEVELOPMENT_PLAN §7 and GAME_DESIGN_FOUNDATION §13: organic
dark fantasy, rose membranes, cyan cilia, gold nutrients/spikes, and distinct dark
materials for each region. Keep menu text and HUD readable; do not replace the game
with the Assets Creator knight example. This pass does not claim an approved final
soundtrack or human M4/M5 playtest.

## Rollout gates

1. Generate deterministic art, VFX and WAVs with the native Assets Creator Rust
   libraries. Capture the exact generator commit, palette/parameters and archive hash.
2. Wire primary/alternate player bodies, enemy silhouettes and boss phases, motes,
   development/evolution visuals, map dressing, backgrounds and menu to the new assets.
   Add sfx only after actual committed gameplay events, not raw input.
3. Run Gines Godot 4.7.2 import, asset coverage and cue tests, full campaign regressions,
   and actual rendered screenshots from the test scenes. Keep reviewable screenshots
   and logs. Source review and player-facing audio/art review are distinct.
