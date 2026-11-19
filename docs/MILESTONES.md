# GENESIS — Milestone Log

**Purpose:** record the decision for every milestone, the evidence behind it and
what remains open. `DEVELOPMENT_PLAN.md` §9 requires each milestone to end in
**PASS**, **REVISE** or **BLOCKED**; this file is where that decision lives.

Decision labels follow the project vocabulary: **Confirmed**, **Proposed**,
**Open**, **Risk**. A milestone decision is only **PASS** when the acceptance
criteria were observed, not assumed.

## Status at a glance

| Milestone | Scope | Automated evidence | Human check | Decision |
|---|---|---|---|---|
| 0 | Godot project setup | PASS (2026-11-19) | PASS (owner, 2026-11-15) | **PASS** |
| 1 | Player movement | PASS (2026-11-19) | **Open** — owner playtest | **REVISE-pending** |
| 2 | Absorption & survival | — | — | Not started |

## How the evidence was produced

Engine: **Godot 4.7.2 stable** (`4.7.2.stable.official.ed1daf0bf`).

On Windows (PowerShell, from the repository root; use the `_console.exe` build so
`print()` output is visible):

```powershell
$godot = "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path game --import
& $godot --headless --audio-driver Dummy --path game res://scenes/test_scene.tscn --quit-after 5
& $godot --headless --audio-driver Dummy --path game res://scenes/movement_test.tscn --quit-after 5
& $godot --headless --audio-driver Dummy --path game --script res://tests/grip_detach_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/demo_verdict_check.gd
& $godot --audio-driver Dummy --path game res://scenes/movement_test.tscn -- --m1-demo --outdir="$(Get-Location)/creative/muse/outputs/experiments"
```

The demo outdir must be absolute: Godot resolves relative paths against `game/`,
so a relative outdir silently becomes an unwritable path.

On Linux, prefix the demo run with `xvfb-run -a -s "-screen 0 960x540x24"` and
use `/tmp/m1` as the outdir. `tools/verify.ps1` runs the same sequence and
propagates every exit code.

Screenshots are committed under `creative/muse/outputs/experiments/`:

| File | Shows |
|---|---|
| `M0_test-scene_960x540_v01.png` | M0 layout at the base viewport |
| `M0_test-scene_1280x720_v01.png` | M0 layout at 1280×720 |
| `M0_test-scene_1920x1080_v01.png` | M0 layout at a 1920×1080 request (1920×1061 client area on the capture machine) |
| `M1_movement-swim_v01.png` | SWIM mid-water, HUD state + speed |
| `M1_movement-crawl_v01.png` | CRAWL along the floor |
| `M1_movement-grip_v01.png` | GRIP under the floating platform |
| `M1_movement-camera_v01.png` | Camera followed the player across the room |

## Milestone 0 — Project setup

- **Objective:** a Godot 4.7.2 project that opens, runs and centralises its
  configuration.
- **Decision:** **PASS** (2026-11-15, owner; merged as PR #2).
- **Acceptance evidence (re-observed 2026-11-19):**
  - `--import` completes on a clean cache.
  - Headless run of `test_scene.tscn` prints `[M0] READY`, all 7 input actions
    report their bound events, exit code 0.
  - Layout markers scale at 960×540, 1280×720 and 1920×1080 (screenshots above).
  - Input is centralised in `project.godot`; code uses action names only.
- **Open items:** gamepad bindings are defined but untested (no controller on
  the build machine) — carried into the M1 human check.

## Milestone 1 — Player movement

- **Objective:** one controllable biological form that swims, crawls and grips
  a surface inside a bounded test room, with a following camera.
- **Automated decision:** **PASS** (2026-11-19).
- **Human decision:** **Open** — see the playtest checklist below.
- **Acceptance evidence:**
  - *Player can move in a bounded environment*: demo autopilot drove the player
    from x=300 to x=1744 inside the 1920×1080 room; bounds assertion passed.
  - *Swimming*: state stayed SWIM in open water; HUD showed the 260 px/s cap
    respected and damping on release (observed in the demo run and swim shot).
  - *Crawling*: floor contact produced `SWIM->CRAWL`, moving at the 130 px/s
    crawl cap, and exiting upward or off an edge returned to SWIM.
  - *Surface gripping*: `SWIM->GRIP` observed under the platform underside;
    `tests/grip_detach_check.gd` passed 6/6 (detach away from the surface, hold
    when pushing in or sliding, on both a floor and a ceiling).
  - *Collision and boundaries*: no position outside the room across all stages;
    no stuck state (12 s per-stage watchdog never fired).
  - *Camera follow*: camera travelled 1444 px with the player and respected the
    room limits.
  - *Harness can fail*: the demo now returns exit code 1 when a criterion fails
    (verified by a headless run that cannot capture screenshots: `DEMO RESULT:
    FAIL`, exit 1), and `tests/demo_verdict_check.gd` covers the verdict logic
    headlessly.
- **Known limitations (not failures):** no gravity model (fluid environment by
  design), floor crawl entry is automatic when moving along the floor while
  pressing sideways, and all geometry is generated in code rather than authored
  scenes.
- **Open items — owner playtest checklist:**
  1. Swim: acceleration, top speed and stopping distance feel controllable.
  2. Floor transition: moving right along the floor with `S` held should crawl,
     not feel sticky or unexpectedly slow.
  3. Crawl → swim: pressing `W` leaves the surface promptly.
  4. Grip: attaching to floor, wall, platform underside and ceiling is
     discoverable; `Shift` detaches; pushing away detaches.
  5. Grip movement direction matches the stick/d-pad on every surface.
  6. Camera does not jitter or lag distractingly, and room limits do not reveal
     out-of-bounds space.
  7. Gamepad pass if a controller is available.
- **Decision rule:** tick PASS if the checklist holds without changes; record
  **REVISE** with the specific item that failed otherwise.

## Milestone 2 — Absorption & survival

Not started. Scope per `BACKLOG.md`: one resource type, one absorbable
organism, absorption feedback, one hostile organism, damage/survival states and
a restart flow — built inside the existing movement room so the prototype has a
single playable scene.
