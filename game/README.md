# GENESIS — Godot project

Milestone 0 setup + Milestone 1 player movement + Milestone 2 absorption and
survival. Godot **4.7.2** (stable). The project opens and launches into the
Milestone 0 test scene; play the prototype at
`res://scenes/prototype.tscn`. Milestone decisions and evidence are recorded in
[`../docs/MILESTONES.md`](../docs/MILESTONES.md).

## Required version

- **Godot 4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`).
- Download from <https://godotengine.org/download/> or the GitHub release
  `godotengine/godot` tag `4.7.2-stable` (Linux x86_64 or Windows x86_64).
- Do **not** use Godot 4.8 beta or any other version without a recorded
  owner decision. Godot 4.4 remains installed on this machine for the
  creative experiments in `creative/muse/experiments/godot-style-test/`
  — do not point this project at it.

## First run on a fresh clone

`.godot/` (the editor cache) is gitignored, so a fresh clone has no
global class cache yet. Until the project has been imported once,
scenes that use `class_name` types (e.g. `PlayerController` in the
movement test) fail with `Could not find type "PlayerController"`.
Import once, from the repository root:

```sh
godot --headless --path game --import
```

(Opening the project in the editor once does the same thing.) After
that, every command below works.

## Run it

From the repository root (replace `godot` with the path to the 4.7.2 binary):

```sh
# Open in the editor
godot --editor --path game

# Play the main scene (the Milestone 0 test scene)
godot --path game

# Play the movement test room (Milestone 1): swim, crawl, grip
godot --path game res://scenes/movement_test.tscn

# Play the absorption & survival prototype (Milestone 2): swim, hold E to feed,
# avoid the predator, retry with E after defeat
godot --path game res://scenes/prototype.tscn

# Headless smoke check: loads the test scene, prints [M0] READY, exits 0
godot --headless --audio-driver Dummy --path game res://scenes/test_scene.tscn --quit-after 5

# Headless smoke check for the movement scene (prints [M1] READY, exits 0)
godot --headless --audio-driver Dummy --path game res://scenes/movement_test.tscn --quit-after 5

# Headless smoke check for the prototype scene (prints [M2] READY, exits 0)
godot --headless --audio-driver Dummy --path game res://scenes/prototype.tscn --quit-after 5

# Demo autopilot: drives the player through swim -> crawl -> grip ->
# detach -> camera follow and saves 4 screenshots, then quits
xvfb-run -a -s "-screen 0 960x540x24" godot --audio-driver Dummy --path game \
  res://scenes/movement_test.tscn -- --m1-demo --outdir=/tmp/m1

# M2 demo autopilot: feed -> get hit -> get defeated -> retry, 3 screenshots
xvfb-run -a -s "-screen 0 960x540x24" godot --audio-driver Dummy --path game \
  res://scenes/prototype.tscn -- --m2-demo --outdir=/tmp/m2
```

```sh
# Regression checks (print results, exit 0 = pass, 1 = failure)
godot --headless --audio-driver Dummy --path game \
  --script res://tests/grip_detach_check.gd
godot --headless --audio-driver Dummy --path game \
  --script res://tests/demo_verdict_check.gd
godot --headless --audio-driver Dummy --path game \
  --script res://tests/absorption_check.gd
godot --headless --audio-driver Dummy --path game \
  --script res://tests/survival_check.gd
godot --headless --audio-driver Dummy --path game \
  --script res://tests/m2_verdict_check.gd
```

### Windows (PowerShell)

Use the `_console.exe` build so `print()` output reaches the terminal. Run from
the repository root:

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"

& $godot --headless --path game --import
& $godot --headless --audio-driver Dummy --path game res://scenes/test_scene.tscn --quit-after 5
& $godot --headless --audio-driver Dummy --path game res://scenes/movement_test.tscn --quit-after 5
& $godot --headless --audio-driver Dummy --path game res://scenes/prototype.tscn --quit-after 5
& $godot --headless --audio-driver Dummy --path game --script res://tests/grip_detach_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/demo_verdict_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/absorption_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/survival_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/m2_verdict_check.gd

# Demo autopilot (needs a real window: headless runs cannot capture screenshots).
# The outdir must be absolute: Godot resolves relative paths against game/.
& $godot --audio-driver Dummy --path game res://scenes/movement_test.tscn `
  -- --m1-demo --outdir="$PWD/creative/muse/outputs/experiments"
& $godot --audio-driver Dummy --path game res://scenes/prototype.tscn `
  -- --m2-demo --outdir="$PWD/creative/muse/outputs/experiments"
```

`tools/verify.ps1` runs all of the above and exits non-zero if any check fails.
Demo screenshots go to a temp folder so verification does not dirty the tracked
evidence; pass `-OutDir` to regenerate it deliberately:

```powershell
pwsh -File tools/verify.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
pwsh -File tools/verify.ps1 -Godot "..." -OutDir "creative/muse/outputs/experiments"
```

### What the demo exit code means

The demo is evidence only if it can fail. `scripts/movement_test.gd` collects
the run's observations, evaluates them in `evaluate_demo()` and exits **1** when
any criterion fails (missing screenshot, leaving the room, missing state, camera
not following). The last line of a run is `[M1] DEMO RESULT: PASS` or `FAIL`.
`tests/demo_verdict_check.gd` covers that verdict headlessly; a headless demo
run reports `FAIL` by design because it cannot save screenshots.

`scripts/prototype.gd` follows the same contract for M2 (`[M2] DEMO RESULT`):
it fails when nothing was absorbed, the predator never landed a hit, no retry
happened, a screenshot is missing, or the player left the room.
`tests/m2_verdict_check.gd` covers that verdict in 7 cases.

### Milestone 2 prototype (`res://scenes/prototype.tscn`)

Same room geometry as the movement test, plus the first loop that can be lost.

- **Feed:** hold `E` within 90 px of a golden mote for 0.75 s. The HUD shows
  channel progress; releasing, leaving range or taking a hit cancels it.
  Feeding drops the swim cap from 260 to 90 px/s, so feeding near the predator
  is a gamble.
- **Survive:** three hearts, 1 s of invulnerability with knockback and flicker.
- **Retry:** defeat shows an overlay; press `E` to respawn at the start.
  Nutrition and eaten motes persist.
- Feedback is visual and HUD only — there are no audio assets in the project
  yet, so no sound is implied anywhere.

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
  shaders/             .gdshader files (e.g. body_rim.gdshader)
  tests/               Headless regression checks (run with --script)
  assets/              Imported art/audio/fonts, grouped by type
  resources/           .tres data resources (balance, evolution data, ...)
```

Movement files (Milestone 1): `scenes/player.tscn` +
`scripts/player.gd` (SWIM / CRAWL / GRIP controller),
`scripts/player_visual.gd` (CHR-002 stage 2 look, ported from the
EXP-001 experiment), `scripts/cilia.gd` (procedural cilia),
`scenes/movement_test.tscn` + `scripts/movement_test.gd` (test room,
camera, HUD, demo autopilot).

Absorption & survival files (Milestone 2): `scenes/prototype.tscn` +
`scripts/prototype.gd` (room, HUD, retry flow, demo autopilot),
`scripts/absorbable.gd` (nutrient mote), `scripts/predator.gd` (hostile
organism), plus absorption/damage/health on `scripts/player.gd`.
Design record: `../docs/superpowers/specs/2026-11-19-m2-absorption-design.md`.

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
| `grip` | Shift | West button (X / Square) |
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
  1280×720 and 1920×1080 are committed as
  `creative/muse/outputs/experiments/M0_test-scene_{960x540,1280x720,1920x1080}_v01.png`;
  the layout scales correctly at each size, and the on-screen readout prints both
  the logical viewport (always 960×540) and the real window size. The 1920×1080
  request produced a 1920×1061 client area on the capture machine, which is why
  that readout differs.

## Notes

- Headless runs (`--headless`) report a dummy square viewport size in
  the `[M0] READY` line — that is a headless display artifact, not a
  project bug. Use an xvfb run for real window-size verification.
- Machines/VMs without an audio device print an ALSA `ERR_CANT_OPEN`
  error on launch. The project has no audio yet, so this is harmless;
  pass `--audio-driver Dummy` to keep headless/CI logs clean.
