# GENESIS — Godot project

Milestone 0 setup + Milestone 1 player movement + Milestone 2 absorption and
survival + Milestone 3 first evolution + Milestone 4 energy for the burst.
Godot **4.7.2** (stable). The project
opens into a procedural main menu (`res://scenes/main_menu.tscn`): Title → Main
→ Map Select → stage; play the prototype directly at
`res://scenes/prototype.tscn`. The menu is procedural UI with no approved art
direction, and its Map Select labels mark unimplemented stages honestly. Its
headless check is `res://tests/menu_check.gd`. Milestone decisions and evidence
are recorded in [`../docs/MILESTONES.md`](../docs/MILESTONES.md).

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

# Play the default main scene (procedural main menu)
godot --path game

# Play the movement test room (Milestone 1): swim, crawl, grip
godot --path game res://scenes/movement_test.tscn

# Play the absorption & survival prototype (Milestone 2): swim, hold E to feed,
# avoid the predator, retry with E after defeat
godot --path game res://scenes/prototype.tscn

# Same scene, Milestone 3: feed to 30 nutrition, press E at the golden alcove
# to evolve, then J to burst. Progress saves to user://genesis_save.cfg;
# start from a clean slate with --fresh-save
godot --path game res://scenes/prototype.tscn -- --fresh-save

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

# M3 demo autopilot: feed -> evolve at the alcove -> kill the predator,
# 4 named screenshots (requirement, evolve, burst, kill)
xvfb-run -a -s "-screen 0 960x540x24" godot --audio-driver Dummy --path game \
  res://scenes/prototype.tscn -- --m3-demo --outdir=/tmp/m3
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
godot --headless --audio-driver Dummy --path game \
  --script res://tests/evolution_check.gd
godot --headless --audio-driver Dummy --path game \
  --script res://tests/energy_check.gd
godot --headless --audio-driver Dummy --path game \
  --script res://tests/m3_verdict_check.gd
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
& $godot --headless --audio-driver Dummy --path game --script res://tests/evolution_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/energy_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/m3_verdict_check.gd

# Demo autopilot (needs a real window: headless runs cannot capture screenshots).
# The outdir must be absolute: Godot resolves relative paths against game/.
& $godot --audio-driver Dummy --path game res://scenes/movement_test.tscn `
  -- --m1-demo --outdir="$PWD/creative/muse/outputs/experiments"
& $godot --audio-driver Dummy --path game res://scenes/prototype.tscn `
  -- --m2-demo --outdir="$PWD/creative/muse/outputs/experiments"
& $godot --audio-driver Dummy --path game res://scenes/prototype.tscn `
  -- --m3-demo --outdir="$PWD/creative/muse/outputs/experiments"
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

The M3 autopilot (`--m3-demo`, `[M3] DEMO RESULT`) fails when the body never
evolved, the burst never defeated the predator, the nutrition left is below the
kill reward (the cost was not paid), any of the four **named** captures is
missing, or the player left the room. Captures are checked by name, so a
duplicated screenshot cannot stand in for a missing one.
`tests/m3_verdict_check.gd` covers that verdict in 8 cases.

Command-line arguments for the prototype:

| Argument | Effect |
|---|---|
| `--m2-demo` / `--m3-demo` | Run the autopilot and exit 0/1 with its verdict. Never reads or writes the player's save. |
| `--outdir=<absolute path>` | Where demo screenshots are written (relative paths resolve against `game/`). |
| `--fresh-save` | Delete `user://genesis_save.cfg` before loading, for a clean first run. |

Engine arguments such as `--quit-after N` must come **before** the `--`
separator; anything after it is passed to the game as a user argument.

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

### Milestone 4 — energy for the spike burst

The evolved burst is now limited by a small energy pool instead of only its
cooldown. Starting values are **Proposed** (not owner-approved) and meant to be
tuned in playtest:

- Maximum **3** energy, cost **1** per burst, passive regeneration **1/s**.
- The HUD shows `Energy ●●○ 2.0/3` only after evolution; the pips dim when a
  burst is unaffordable.
- A burst that is unavailable (not evolved, cooling down, or out of energy) is
  rejected without spending energy or damaging anything.
- Energy starts full on a fresh run and after retry/revive. It is **not**
  saved: the existing evolved/nutrition save behavior is unchanged.
- Pausing halts energy regeneration (player and predator are pausable even
  though the scene root stays always-on for the pause key).
- Energy never gates movement, absorption, evolution or required progress.

Design record: `../docs/superpowers/specs/2026-11-19-m4-energy-design.md`.
Regression check: `tests/energy_check.gd` (9 cases).

### Milestone 5 — the first boss encounter (owner check open)

Play the arena at `res://scenes/boss_test.tscn`. Collect the three motes, evolve
at the alcove to open the gate, then read the Rot Bloom's telegraph and burst
only while its core is exposed (`J`). Defeat returns you to the shelter with
evolution and nutrition kept and the boss reset.

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"

# Play from a clean slate
& $godot --path game res://scenes/boss_test.tscn -- --fresh-save

# Headless smoke and regressions
& $godot --headless --audio-driver Dummy --path game res://scenes/boss_test.tscn --quit-after 5 -- --fresh-save
& $godot --headless --audio-driver Dummy --path game --script res://tests/boss_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/m5_verdict_check.gd

# Windowed demo: four named captures, DEMO RESULT: PASS / FAIL
& $godot --audio-driver Dummy --path game res://scenes/boss_test.tscn `
  -- --m5-demo --outdir="$PWD/creative/muse/outputs/experiments" --fresh-save
```

The full runner (`pwsh -File tools/verify.ps1 -Godot $godot`) now includes the
M5 smoke and demo; automated evidence was observed on 2026-11-21. The **owner
feel check is still open** — see the checklist in
[`../docs/MILESTONES.md`](../docs/MILESTONES.md). No milestone PASS is implied.

The default main scene is `res://scenes/main_menu.tscn`. The M0 scene
`res://scenes/test_scene.tscn` shows a scaling
marker layout and a live input readout. Pressing `Esc`/`P` toggles a
PAUSED label. In screenshot mode it feeds two real key events (D, E)
through the input system so the readout proves the actions fire:

```sh
# Save a screenshot of the running scene and quit (used for scaling checks)
godot --path game res://scenes/test_scene.tscn --resolution 1280x720 -- --screenshot=/tmp/m0.png
```

### Map runner (`res://scenes/map_runner.tscn`)

`res://scenes/map_runner.tscn` loads `res://resources/maps/map01.json`, a
generated runtime copy of the canonical `docs/maps/map01.json`. The planned boss
`the_drifter` currently spawns a `Predator`, a **Proposed** placeholder following
the map data's `fallback_until_implemented` field. Maps 02–08 use the
parameterized `map_stage.gd` scenes listed below, each with a full-map test.
Every runtime map copy is byte-identical to its canonical file and guarded by a
SHA256 check in `tools/check_maps.ps1`. These are runtime prototypes with
placeholder abilities, bosses and endings — not a milestone PASS, and no art
approval is implied.

`res://scenes/map02.tscn` ("The Divide") is also runnable through the same
parameterized stage: its planned boss `the_splitter` uses the documented
`built_from: Predator` fallback and remains a **Proposed placeholder** (not an
approved enemy or art), and there is no milestone PASS implied.

`res://scenes/map04.tscn` ("The Pulse") is runnable too: its planned boss
`the_pulse_maw` has no `built_from`, so it uses the documented Rot Bloom fallback
as a clearly labeled BloomBoss **Proposed placeholder** (design-only, not an
approved enemy or art), the hazard band is an inert slab because timed damage is
still Open, and no milestone PASS is implied.

`res://scenes/map05.tscn` ("The Calcium Vault") is runnable: its upgrade is
entirely planned, so `body_contraction` and `dash` load only as explicitly
acknowledged **planned-grant placeholders** (fallback: swim/grip/burst) — they
are not implemented abilities; its planned boss `the_vine_lash` has no
`built_from` and uses the labeled BloomBoss **Proposed placeholder**, the hazard
is an inert slab because contact damage is still Open, and no milestone PASS or
art approval is implied.

`res://scenes/map06.tscn` ("The Budding Field") is runnable: its `run`, `jump` and
`body_part_strike` grants are planned-only and load just as explicitly
acknowledged **planned-grant placeholders** (fallback: swim/grip/burst) — not
implemented abilities; its planned boss `the_gnawer` has no `built_from` and uses
the labeled BloomBoss **Proposed placeholder**, and no milestone PASS or art
approval is implied.

`res://scenes/map07.tscn` ("The Neural Bloom") is runnable: its `double_jump`,
`glide` and `chemical_veil` grants are planned-only and load just as explicitly
acknowledged **planned-grant placeholders** (fallback: swim/grip/burst) — not
implemented abilities; its planned boss `the_sentinel` has no `built_from` and
uses the labeled BloomBoss **Proposed placeholder**, the sensor tripwire band is
an inert slab because tracking damage is still Open, and no milestone PASS or
art approval is implied.

`res://scenes/map08.tscn` ("The Passage") is the runnable **finale placeholder**:
its `integrated_form` and `combo_mastery` grants are planned-only and load just
as explicitly acknowledged placeholders (fallback: swim/grip/burst), not
implemented abilities or combo inputs; its planned boss `the_last_overgrowth`
uses the labeled BloomBoss **Proposed placeholder** and its `final_membrane` is
a planned gate built as an inert slab. This is a signpost toward birth, not a
milestone PASS or approved art — the birth cinematic remains **Open** (no birth
sequence is implemented).

`res://scenes/map09.tscn` ("The Convergence") is the runnable **ante-birth final
boss stage**: its boss `the_convergence` is implemented and resolves to the new
`FinalBoss` (a two-phase BloomBoss subclass — 12 HP, the learned 0.6 / 1.5 rhythm
in phase 1, then a `second_wind` at 6 HP with 0.45 / 1.1 timings and a readable
`phase_changed` marker). Its `final_form` upgrade is planned-only and its
`integrated_form` grant loads as an explicitly acknowledged placeholder (fallback:
the existing spike burst); no combo input, new resource or birth cinematic is
invented. map08 now unlocks map09, and map09's exit signposts birth while the
cinematic itself stays **Open**. No milestone PASS, owner feel check or approved
art is implied.

```powershell
# Play map01 from the JSON-driven runner
& $godot --path game res://scenes/map_runner.tscn

# Play any full stage (02-09): feed -> evolve -> gate -> boss -> completion
& $godot --path game res://scenes/map03.tscn
& $godot --path game res://scenes/map08.tscn
& $godot --path game res://scenes/map09.tscn

# Headless: each map has its own full-map rule test
& $godot --headless --audio-driver Dummy --path game --script res://tests/map_runner_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/map03_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/map08_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/map09_check.gd

# Headless autopilot for a stage (passes even without a display)
& $godot --headless --audio-driver Dummy --path game res://scenes/map08.tscn -- --map-demo=map08
& $godot --headless --audio-driver Dummy --path game res://scenes/map09.tscn -- --map-demo=map09

# All maps, drift guards, and every registered check
pwsh -File tools/check_maps.ps1
pwsh -File tools/verify.ps1 -Godot $godot
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
| `attack` | J | North button (Y / Triangle) |
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
