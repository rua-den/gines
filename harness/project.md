# GENESIS — Game Harness Project Profile

**This file is the default project for the game harness.** Every game skill
reads it first. If a skill runs in a repository without it, the skill must ask
for the project facts instead of guessing.

Keep this file to facts an agent needs **before** opening the detailed docs.
When a detail already lives in a source document, point at it instead of
copying it.

## Project

- **Game:** GENESIS — The Journey Before Life.
- **Genre:** 2D side-scrolling action Metroidvania; one interconnected
  biological world inside the womb, from a single cell to birth.
- **Development model:** solo developer + AI. No fixed deadline.
- **Platform:** PC / Steam first.
- **Stage:** Pre-production; Milestone 4 (energy for the burst) passed automated
  checks, owner feel check open.
- **Emotional target:** the love, effort and sacrifice that make a new life
  possible.
- **Never:** turn this game into a biology simulation, or promote a Muse
  exploration to an approved direction without the owner.

## Engine

- **Godot 4.7.2 stable only** (`4.7.2.stable.official.ed1daf0bf`). Do not use
  4.8 beta or the 4.4 install kept for creative experiments.
- Project root: `game/`. Main scene: `res://scenes/test_scene.tscn`. Playable
  prototype: `res://scenes/prototype.tscn`.
- Base viewport **960×540**, stretch `canvas_items`, aspect `expand`, renderer
  `gl_compatibility`.
- Input actions are centralized in `game/project.godot` and must be read with
  `Input.is_action_pressed(...)` / `event.is_action_pressed(...)`; never raw
  keycodes.
- Naming: files/folders `snake_case`; scene root nodes `PascalCase` matching the
  file; one script per scene where 1:1. Full table in `game/README.md`.
- The engine is **not on this machine's `PATH`**. Every command that needs it
  takes an explicit path. On Windows use the `_console.exe` build so `print()`
  output reaches the terminal.
- First run on a fresh clone needs an import:
  `godot --headless --path game --import`.

## Commands

Run from the repository root. Keep engine arguments before the `--` separator;
anything after it is passed to the game.

| Purpose | Command |
|---|---|
| Full game verification | `pwsh -File tools/verify.ps1 -Godot "<path>"` |
| Full verification without a display | `pwsh -File tools/verify.ps1 -Godot "<path>" -SkipDemo` |
| Harness structure check | `pwsh -File harness/scripts/check.ps1` |
| Verification report | `pwsh -File harness/scripts/evidence.ps1 -Godot "<path>"` |
| One regression check | `godot --headless --audio-driver Dummy --path game --script res://tests/<name>.gd` |
| Smoke a scene | `godot --headless --audio-driver Dummy --path game <scene> --quit-after 5` |
| Play the prototype | `godot --path game res://scenes/prototype.tscn -- --fresh-save` |

`-SkipDemo` is honest only when no display exists; say so in the report. A
headless run cannot capture screenshots, so the demo autopilots report FAIL by
design without a window.

## Repository map

```text
game/            Godot project (project.godot, scenes/, scripts/, shaders/, tests/, resources/, assets/)
docs/            Vision, development plan, milestones, backlog, creative plan, specs, plans
creative/muse/   Muse workspace: briefs, outputs, experiments, reference
tools/verify.ps1 One-command game verification
harness/         This harness: profile, templates, scripts, rules
.agents/skills/  Agent skills (Superpowers + game-* skills)
.opencode/commands/  Slash commands for the game skills
```

Sources of truth: `README.md`, `AGENTS.md`, `docs/GAME_DESIGN_FOUNDATION.md`,
`docs/DEVELOPMENT_PLAN.md`, `docs/MILESTONES.md`, `docs/BACKLOG.md`,
`creative/muse/README.md`.

## Decision rules

Every design statement carries a status:

- **Confirmed** — explicitly selected by the project owner.
- **Proposed** — a recommended direction, not locked.
- **Open** — needs a future decision.
- **Risk** — may threaten quality, feasibility or progression.

Creative work uses its own statuses: **Exploration**, **Shortlisted**,
**Candidate**, **Approved direction**, **Superseded**. Only the project owner
approves a direction.

Milestone verdicts are **PASS**, **REVISE** or **BLOCKED**, recorded in
`docs/MILESTONES.md`. A checked backlog box is not a milestone PASS. A failed
test is a reason to investigate and recover, not to abandon the work.

Never promote a proposal to a requirement, or an exploration to approved art,
on your own. Never write a PASS that was not observed in a real run.

## Scope guard

Optimize for a finished, compelling **vertical slice**, not maximum feature
count. Prototype the smallest playable loop before broad content: movement,
survival/absorption, then the first meaningful evolution.

Explicitly out of scope for now (see `docs/BACKLOG.md`): full world map,
multiple complete regions, all developmental stages, full evolution tree, five
separate resource systems, multiple bosses, final art/UI/soundtrack, Steam
release infrastructure.

When scope grows, state the player-facing value, the implementation cost, and
what should be deferred. Protect progression from softlocks: a permanent
evolution choice must never make required content impossible.

## Creative

- The Muse workspace is `creative/muse/`; start with its `README.md` and the
  relevant brief.
- Save visual explorations under `creative/muse/outputs/` in the documented
  category folders with the concept-ID naming convention.
- Preserve original outputs and prompts; create a new version instead of
  overwriting.
- Keep concept notes with useful outputs: intent, gameplay hypothesis,
  strengths, risks, next iteration.
- Treat generated content as **exploration** until the owner approves it. Do not
  label anything "Approved direction" or update official decisions.
- Favor distinct, readable, reproducible 2D concepts; account for
  solo-development animation and asset cost.
- Do not imitate the recognizable style or assets of named reference games.

## Sources

- `README.md` — project status, documentation index, working principles.
- `AGENTS.md` — repository rules for coding agents, Superpowers workflow.
- `game/README.md` — install, run, verify, layout, naming, input, scaling.
- `docs/GAME_DESIGN_FOUNDATION.md` — vision, pillars, core loop.
- `docs/DEVELOPMENT_PLAN.md` — phases, gates, risks, governance.
- `docs/MILESTONES.md` — milestone decisions and evidence.
- `docs/BACKLOG.md` — ordered work, acceptance criteria, out-of-scope list.
- `docs/CREATIVE_EXPLORATION_PLAN.md` — Muse track and review criteria.
- `creative/muse/README.md` — output folders, concept naming, review rules.
- `harness/templates/` — design, playtest, milestone and art report shapes.
