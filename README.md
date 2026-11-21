# GENESIS — The Journey Before Life

A solo + AI 2D action Metroidvania about the journey of a new life, from a single cell to birth.

> Every life begins with a journey. *(Provisional tagline.)*

## Project status

**Stage:** Pre-production — Phase 3 integration / Phase 4 map-runtime prototype.
**Current milestone:** Milestones 0–3 passed automated checks and owner playtest. Milestone 4 (energy) and Milestone 5 (first boss) have observed automated PASS; their **owner feel checks are Open** — see the [Milestone Log](docs/MILESTONES.md). No milestone PASS is implied by the checks below.
**Verified build (2026-11-21):** Godot 4.7.2; `tools/verify.ps1` → 42 checks; `tools/check_maps.ps1` → 8 maps, 540 checks; harness check → 65 checks.
**Playable now:** a continuous region slice (prototype → Rot Bloom arena), `res://scenes/map_runner.tscn` (map01), and `res://scenes/map02.tscn` … `map08.tscn` — each with its own headless full-map test and autopilot. Planned abilities, bosses and the finale are **Proposed placeholders** (fallbacks documented in each map JSON); they are not implemented features, approved art, or a milestone PASS. The birth cinematic remains Open.
**Initial target:** A 4–6 hour PC game, with scope validated through a vertical slice.

## Documentation

- [Development Plan](docs/DEVELOPMENT_PLAN.md) — roadmap, milestones, gates and risks.
- [Milestone Log](docs/MILESTONES.md) — decisions (PASS / REVISE / BLOCKED), evidence and open items per milestone.
- [Game Design Foundation](docs/GAME_DESIGN_FOUNDATION.md) — vision, pillars, core loop and design direction.
- [Creative Exploration Plan](docs/CREATIVE_EXPLORATION_PLAN.md) — Muse AI creative track, review criteria and first art milestone.
- [Muse Workspace](creative/muse/README.md) — instructions for Muse, briefs, output folders and concept naming.
- [Game Harness](harness/README.md) — game-making skills, slash commands, project profile and structural validator.
- [Initial Backlog](docs/BACKLOG.md) — first implementation tasks and acceptance criteria.
- [Superpowers Setup](docs/SUPERPOWERS_SETUP.md) — repo-local Superpowers installation and workflow.
- [Agent Instructions](AGENTS.md) — repository-level rules for coding agents.

## Development

The game lives in [`game/`](game/README.md) (Godot 4.7.2). See
[game/README.md](game/README.md) for how to install, run and verify the
project.

## One-sentence vision

Play through the development of a human life inside the mother's womb: explore a fantastical biological world, absorb matter, evolve your body, overcome challenges, and discover the love and sacrifices that made your life possible.

## Working principles

- Build a playable prototype before expanding content.
- Treat interview decisions as design input, not an excuse to implement every idea.
- Label decisions as **Confirmed**, **Proposed**, **Open**, or **Risk**.
- Keep the scope realistic for a solo developer working with AI.
- Every milestone must produce something testable.
- Treat Muse outputs as explorations until the project owner explicitly approves a direction.
