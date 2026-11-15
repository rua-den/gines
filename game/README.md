# GENESIS — Godot project

Milestone 0 setup. Godot **4.7.2** (stable). The project opens and launches
into a test scene with no gameplay yet — this folder is scaffolding for the
Milestones 1+ prototype.

## Required version

- **Godot 4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`).
- Download the Linux x86_64 binary from
  <https://godotengine.org/download/> (or the GitHub release
  `godotengine/godot` tag `4.7.2-stable`).
- Do **not** use Godot 4.8 beta or any other version without a recorded
  owner decision. Godot 4.4 remains installed on this machine for the
  creative experiments in `creative/muse/experiments/godot-style-test/`
  — do not point this project at it.

## Run it

From the repository root (replace `godot` with the path to the 4.7.2 binary):

```sh
# Open in the editor
godot --editor --path game

# Play the main scene (the Milestone 0 test scene)
godot --path game

# Headless smoke check: loads the test scene, prints [M0] READY, exits 0
godot --headless --audio-driver Dummy --path game res://scenes/test_scene.tscn --quit-after 5
```

The main scene is `res://scenes/test_scene.tscn`. It shows a scaling
marker layout and a live input readout. Pressing `Esc`/`P` toggles a
PAUSED label. In screenshot mode it feeds two real key events (D, E)
through the input system so the readout proves the actions fire:

```sh
# Save a screenshot of the running scene and quit (used for scaling checks)
godot --path game res://scenes/test_scene.tscn --resolution 1280x720 -- --screenshot=/tmp/m0.png
```

## Layout

```text
game/
  project.godot        Engine + display + input configuration
  icon.svg             Project icon (teal membrane + gold nucleus)
  README.md            This file
  scenes/              .tscn scenes (snake_case, e.g. test_scene.tscn)
  scripts/             .gd scripts (snake_case, 1:1 with their scene where applicable)
  assets/              Imported art/audio/fonts, grouped by type
  resources/           .tres data resources (balance, evolution data, ...)
```

Empty folders carry a `.gitkeep` so the layout survives a fresh clone.
`.godot/` (editor cache) is gitignored; `.import` files **are** committed.

## Naming conventions

- Files and folders: `snake_case`, no spaces (`test_scene.tscn`).
- Scene root node: `PascalCase`, matching its file (`TestScene`).
- Child nodes: `PascalCase`, descriptive (`UI`, `Player`, `ShelterBloom`).
- Scripts: `snake_case`, matching their scene where 1:1.
- Input actions: `snake_case` verbs (`move_left`, `interact`, `pause`).
- GDScript: `snake_case` functions/variables, `SCREAMING_SNAKE_CASE`
  constants — standard GDScript style.

## Input actions (centralised in project.godot)

| Action | Keyboard | Gamepad |
|---|---|---|
| `move_left` | A / Left | Left stick left, D-pad left |
| `move_right` | D / Right | Left stick right, D-pad right |
| `move_up` | W / Up | Left stick up, D-pad up |
| `move_down` | S / Down | Left stick down, D-pad down |
| `interact` | E / Space | South button (A / Cross) |
| `pause` | Esc / P | Start |

Game code must use `Input.is_action_pressed("...")` /
`event.is_action_pressed("...")` — never raw keycodes. Gamepad bindings
are defined but were not exercised in the automated run (no controller
on the build machine); they need a human pass.

## Resolution and scaling

- Base viewport: **960×540** (same as the EXP-001/EXP-002 experiments).
- Stretch mode: `canvas_items`, aspect `expand`. The logical viewport
  stays 960×540; the canvas scales to the window, and wider windows
  reveal more of the scene instead of letterboxing.
- Renderer: GL Compatibility (`gl_compatibility`), same as the
  experiments — chosen for broad PC compatibility.
- Verification: the test scene anchors gold corner markers, edge ticks
  and a border frame to the viewport edges. Screenshots at 960×540,
  1280×720 and 1920×1080 (see `creative/muse/outputs/experiments/
  M0_test-scene_*_v01.png`) show the layout scaling correctly at each
  size; the on-screen readout prints both the logical viewport
  (always 960×540) and the real window size.

## Notes

- Headless runs (`--headless`) report a dummy square viewport size in
  the `[M0] READY` line — that is a headless display artifact, not a
  project bug. Use an xvfb run for real window-size verification.
- Machines/VMs without an audio device print an ALSA `ERR_CANT_OPEN`
  error on launch. The project has no audio yet, so this is harmless;
  pass `--audio-driver Dummy` to keep headless/CI logs clean.
