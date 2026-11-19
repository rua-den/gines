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
| 1 | Player movement | PASS (2026-11-19) | PASS (owner playtest, 2026-11-19) | **PASS** |
| 2 | Absorption & survival | PASS (2026-11-19) | PASS (owner playtest, 2026-11-19) | **PASS** |
| 3 | First evolution | PASS (2026-11-19) | PASS (owner playtest, 2026-11-19) | **PASS** |
| 4 | Energy for the burst | PASS (2026-11-19) | **Open** — owner feel check | **Automated PASS / human Open** |

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
& $godot --headless --audio-driver Dummy --path game --script res://tests/absorption_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/survival_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/m2_verdict_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/evolution_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/energy_check.gd
& $godot --headless --audio-driver Dummy --path game --script res://tests/m3_verdict_check.gd
& $godot --audio-driver Dummy --path game res://scenes/movement_test.tscn -- --m1-demo --outdir="$(Get-Location)/creative/muse/outputs/experiments"
& $godot --audio-driver Dummy --path game res://scenes/prototype.tscn -- --m2-demo --outdir="$(Get-Location)/creative/muse/outputs/experiments"
& $godot --audio-driver Dummy --path game res://scenes/prototype.tscn -- --m3-demo --outdir="$(Get-Location)/creative/muse/outputs/experiments"
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
| `M2_prototype-absorb_v01.png` | A mote consumed; nutrition 10, health full |
| `M2_prototype-hit_v01.png` | Predator contact: health 2, player flickering invulnerable |
| `M2_prototype-retry_v01.png` | Defeat overlay: all health lost, "press E to retry" |
| `M3_prototype-requirement_v01.png` | At the golden alcove: "EVOLUTION — press E (30/30 nutrition)" |
| `M3_prototype-evolve_v01.png` | After evolving: spike ring around the body, "EVOLVED — J to burst" |
| `M3_prototype-burst_v01.png` | The burst ring expanding, predator inside it, three hearts |
| `M3_prototype-kill_v01.png` | Predator defeated and fading, nutrition 15 |

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
- **Human decision:** **PASS** (owner playtest, 2026-11-19).
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
- **Owner playtest result:** **PASS** (2026-11-19); no revisions requested.
  The checklist below records what was reviewed:
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

## Milestone 2 — Absorption & survival

- **Objective:** the first loop that can be lost — food that takes time to take,
  and an organism that punishes taking it at the wrong moment.
- **Automated decision:** **PASS** (2026-11-19).
- **Human decision:** **PASS** (owner playtest, 2026-11-19). The owner found the
  absorption and enemy interaction understandable and acceptable.
- **Design record:** [`superpowers/specs/2026-11-19-m2-absorption-design.md`](superpowers/specs/2026-11-19-m2-absorption-design.md)
  — the three absorption verbs considered (contact snatch, grip-feed,
  channel-hold) and why channel-hold was chosen.
- **Acceptance evidence:**
  - *Minimal resource model*: one value (`player.nutrition`) plus a
    `nutrition_gained` signal; nothing else. HUD shows `Nutrition N`.
  - *Absorbable organism*: four nutrient motes; holding `interact` within 90 px
    for 0.75 s consumes one, once. `tests/absorption_check.gd` passes 6/6
    (completes, release resets, leaving range resets, no double absorb, damage
    cancels, feeding drag).
  - *Absorption feedback*: the mote pulses faster while channelled, bursts on
    consumption, the HUD nutrition line flashes, and the HUD reports channel
    percentage. No audio — the project has no audio assets yet; this is stated
    rather than implied.
  - *Hostile organism*: one predator patrols x 1000–1520, chases inside 420 px,
    deals 1 damage closer than 66 px, and idles when the player is dead.
    Chase speed 165 px/s is below the 260 px/s swim cap, so fleeing is always
    possible.
  - *Damage and survival*: 3 health, 1.0 s invulnerability, knockback and
    flicker; defeat emits `died` exactly once. `tests/survival_check.gd` passes
    6/6 (contact, invulnerability blocks, expires, defeat once, revive, chase
    vs patrol).
  - *Recovery flow*: defeat shows an overlay; `interact` revives in place and
    returns the player to the start position. Nutrition and consumed motes
    persist — retrying never restarts the application.
  - *Harness can fail*: `--m2-demo` exits 1 on any failed criterion;
    `tests/m2_verdict_check.gd` covers that verdict (7 cases). Verified in
    practice: the first demo run failed (stage 1 timed out because the
    autopilot collided with the floating platform while the predator waited
    below), which is exactly the defect the exit code was built to surface.
- **Known limitations (not failures):**
  - Damage is distance-based, not a physical collision, so a hit can register
    slightly before bodies visually touch at 66 px against a 55 px radius.
  - One predator, four motes, no respawn of consumed motes, no resource loss on
    death (foundation §9 mentions dropped resources — deliberately deferred).
  - `prototype.gd` duplicates the room-drawing helpers from `movement_test.gd`;
    with two scenes a shared module is not yet worth the churn.
- **Owner playtest result:** **PASS** (2026-11-19); no revisions requested.
  The checklist below records what was reviewed:
  1. Is it clear that a mote must be channelled (`E` held) rather than touched?
  2. Does the 0.75 s channel feel like commitment, or like waiting?
  3. Does the feeding drag (260 → 90 px/s) read as a cost, or as a bug?
  4. Is the predator's aggro range readable? Can you always break away?
  5. Do three hearts feel fair against three-hit defeat, and is the retry
     prompt noticed?
  6. Does the loop read without instructions: see mote → feed → see predator →
     avoid or get hit → retry?

## Milestone 3 — First evolution

- **Objective:** turn the absorbed resource into a permanent, visible body change
  with one usable ability, and keep it across a restart.
- **Automated decision:** **PASS** (2026-11-19).
- **Human decision:** **PASS** (owner playtest, 2026-11-19); the first evolution
  and its ability were acceptable to the owner.
- **Design record:** [`superpowers/specs/2026-11-19-m3-evolution-design.md`](superpowers/specs/2026-11-19-m3-evolution-design.md)
  — why 30 nutrition once, why a radial burst, and why the transformation itself
  creates space.
- **Decision status:** every number below is **Proposed** by the agent under the
  owner's standing "keep going and invent what is missing" instruction. None of
  it is owner-approved; adjusting a cost or a cooldown is not a design reversal.
- **Acceptance evidence:**
  - *One evolution requirement*: 30 nutrition, spent once, checked by
    `player.can_evolve()`; a refused attempt flashes the HUD and prints the
    shortfall. Covered by `tests/evolution_check.gd` (case 1–2).
  - *One evolution zone*: a golden alcove at (1720, 420), radius 120 px, past
    the predator's patrol band. `interact` inside it evolves; the HUD shows
    `EVOLUTION — press E (30/30 nutrition)` and dims when the cost is not met.
    The site dims permanently once used.
  - *One body transformation*: fourteen golden spikes around the body, breathing
    slowly; the body also brightens. Visible in `M3_prototype-evolve_v01.png`.
  - *New body part → one ability*: `spike_burst` (radius 130 px, 1 damage,
    0.8 s cooldown, `attack` = J / gamepad button 3). Unavailable before
    evolution, usable after; out-of-range predators are spared; the cooldown
    holds; two bursts kill. All six behaviours are asserted headlessly.
  - *Evolution feedback*: the alcove ring, a HUD state change, an expanding
    burst ring per shot (`scripts/burst_ring.gd`), a 1.5 s grace window and a
    120 px shockwave that leaves nearby organisms reeling for 0.8 s. Still no
    audio — stated, not implied.
  - *Save and reload*: `SaveState` writes `evolved` and `nutrition` to
    `user://genesis_save.cfg`; a second scene run loads the evolved body and
    marks the alcove used (asserted end-to-end, not just as a dictionary
    round-trip). Demo runs never read or write the player's save;
    `--fresh-save` clears it.
  - *Harness can fail*: `--m3-demo` requires four **named** captures
    (`requirement`, `evolve`, `burst`, `kill`), the evolution, the kill, a
    nutrition floor and room bounds, and exits 1 otherwise.
    `tests/m3_verdict_check.gd` covers that verdict in 8 cases, including a
    duplicated screenshot that must not substitute for a missing one.
    Observed in practice: the first M3 demo run **failed** (the hunt stage
    timed out because the autopilot charged the predator head-on), which is the
    defect the exit code exists to surface.
- **Known limitations (not failures):**
  - One evolution, no branch, no second site. The body changes exactly once.
  - The save holds progress only: position, eaten motes and the predator's death
    are not persisted; relaunching restarts the room with an evolved body.
  - The predator has no physical presence: with damage radius-based (66 px), it
    can sit inside the player's 55 px body without pushing it. Visible in some
    frames; harmless mechanically, questionable as feel.
  - `prototype.gd` still duplicates the M1 room-drawing helpers and now also
    carries both demo autopilots; the file is the largest in the project and is
    the first candidate for extraction once a third scene needs the same room.
- **Risks:**
  - *The predator camps the alcove.* Detection (420 px) reaches the site, so the
    first evolution happens with a predator arriving. The grace window plus
    shockwave (agent-proposed) paper over it; the owner may prefer moving the
    site or the patrol band instead.
  - *The demo proves possibility, not fun.* The autopilot needed several real
    fixes (orbit instead of charging, capture timing, the shockwave) before it
    survived three hearts. That is evidence the fight is tight, not that it is
    enjoyable.
- **Owner playtest result:** **PASS** (2026-11-19); no revisions requested.
  The checklist below records what was reviewed:
  1. Before arriving, is the 30-nutrition requirement legible from the HUD?
  2. Does the golden alcove read as interactive without being told?
  3. Does the spike ring read as a permanent change rather than a buff icon?
  4. Does `J` read as coming from the spikes (ring timing and reach)?
  5. Does the transformation grace + shockwave feel like a payoff, or like the
     game taking the body away for a moment?
  6. Is the predator a threat you can beat rather than a wall you must kite?
  7. Relaunch after evolving: does a persisted body feel right, or does it need
     a visible "progress saved" cue?

## Milestone 4 — Energy for the burst

- **Objective:** make the evolved burst a repeated decision by giving it a small
  spend-and-recover pool, without touching movement, absorption or progression.
- **Automated decision:** **PASS** (2026-11-19).
- **Human decision:** **Open** — see the playtest checklist below.
- **Design record:** [`superpowers/specs/2026-11-19-m4-energy-design.md`](superpowers/specs/2026-11-19-m4-energy-design.md)
  — energy on the existing burst rather than a boss or a second ability, so the
  spend/recover question is isolated.
- **Implementation plan:** [`superpowers/plans/2026-11-19-m4-energy.md`](superpowers/plans/2026-11-19-m4-energy.md).
- **Decision status:** every value below is **Proposed** by the agent; tuning a
  capacity, cost or regeneration rate is not a design reversal.
- **Acceptance evidence:**
  - *Energy pool and HUD*: `PlayerController` exposes `MAX_ENERGY` 3,
    `BURST_ENERGY_COST` 1, `ENERGY_REGEN_RATE` 1/s and mutable `energy`. The
    prototype HUD shows `Energy ●●○ 2.2/3` only after evolution — visible in the
    re-generated `M3_prototype-burst_v01.png` capture; the line is hidden in the
    pre-evolution `M3_prototype-requirement_v01.png`.
  - *Exact spend*: one accepted burst subtracts exactly one energy and one
    predator health; `tests/energy_check.gd` 9/9 covers the full contract.
  - *No side effects on refusal*: pre-evolution, cooldown-blocked and
    energy-starved bursts return false, spend no energy and deal no damage. The
    starved case starts at 0.5 (not 0) so a spend that ignored affordability
    would be visible; the cooldown case carries a predator and asserts it takes
    exactly one hit.
  - *Pause*: the scene root stays `PROCESS_MODE_ALWAYS` for the pause key, but
    the player and predator are `PROCESS_MODE_PAUSABLE`, so pausing does not
    regenerate energy or move the fight. A headless case asserts energy is
    unchanged after 30 paused physics frames.
  - *Regeneration and cap*: energy recovers with elapsed physics time and never
    exceeds `MAX_ENERGY`; the check measures ~1 energy per second and the cap.
  - *Retry/revive*: `revive()` refills energy to maximum; health behavior is
    unchanged.
  - *Save behavior*: `save_state.gd` was not modified. The check saves an
    evolved player with spent energy and asserts the file contains only
    `evolved`/`nutrition`, while a fresh player starts full; the existing M3
    scene save flow still passes end-to-end.
  - *Harness can fail*: before implementation the check failed with access
    errors for the missing `energy`/`MAX_ENERGY` members and exited 1; after
    implementation it reports `ALL PASS`, and `tools/verify.ps1` includes it.
    The full runner passed 15/15 checks on 2026-11-19.
- **Known limitations (not failures):**
  - Regeneration is continuous, with no delay after an attack. The spec lists
    the delayed alternative as open.
  - The HUD shows a fractional value while regenerating; pips use the whole
    number so the numeric part carries the partial state.
  - No energy pickups, no second ability, no boss, and still no audio assets.
  - A rejected burst is silent (no signal, no cue) apart from the dimmed HUD
    line. Adding refusal feedback is deferred to the owner playtest, because
    the milestone exists to judge whether the cost reads at all.
- **Risks:**
  - *The values may make the burst too available or too scarce.* 3 capacity with
    1/s regeneration lets the M3 demo still defeat the predator, so required
    progress is intact; whether it is a *good* limit is exactly what the owner
    playtest decides.
  - *A visible energy bar can imply a resource economy the game does not have.*
    It is deliberately hidden before evolution and only limits an optional
    ability.
- **Open items — owner playtest checklist:**
  1. Is the `Energy` line legible after evolution without reading the README?
  2. Does spending 1 of 3 feel like a cost, or does regeneration erase it?
  3. Does waiting for energy read as a decision, or as downtime?
  4. Does the pip/number readout communicate affordability before pressing `J`?
  5. Should regeneration start immediately (proposed) or after a short delay?
  6. Does the limit change how you fight the predator in a way you enjoy?

