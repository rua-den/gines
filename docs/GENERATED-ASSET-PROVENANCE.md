# Genesis / Gines: Bioluminescent Tissue

This original offline asset set interprets Gines' dark-fantasy biological ecosystem.
The player has a coral membrane, a golden nucleus and mint cilia. Its evolved form has
extended golden spines; the predator is vermilion, Rot Bloom has poison-green nodes,
and the finale is a dark purple-and-gold convergence. World art stays dark and soft
toward the center so collision surfaces, hazards and HUD remain readable.

- Entity/marker sprites are centered on transparent canvases.
- Stone, growth, hazard and gate are 64×64 seamless materials.
- One 64×64 illustrated UI panel, an app icon, 2 common backdrops, 9 map-specific
  960×540 backdrops, and an eight-frame one-shot 24 FPS Spike Burst sheet.
- Five deterministic mono 44.1 kHz combat/progression sounds: pickup, burst,
  damage, evolve and death, with separate parameter files.
- The Gines theme uses the existing Asset Creator Rust `ac-vfx`, `ac-export`
  and `ac-sfx` workspace; the visuals are bespoke generated assets via the native
  theme recipe. No AI model, network provider or GPU is used during generation.

Integration: copy the `assets/genesis/` subtree directly into Gines' `game/assets/`.
Terrain should tile at native scale; player art assume the established 0.5 visual
body scale and existing collider. Do not use sprite bounds for any physics or hit
detection. The shipped creative concepts need not be modified to use this set.

Generator commit: `5014c032a8f5444d705e091dc12d42eff1a51233`. Gines validation target: `e33a7b8`.
