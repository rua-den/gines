# GENESIS Game Harness — Design

**Date:** 2026-11-20
**Status:** Confirmed by the project owner (2026-11-20)
**Scope:** Tooling and agent workflow only. No gameplay code, no engine change.

## Intent

GENESIS is built by one developer working with AI agents. The repository already
has strong Superpowers process skills, a Godot project with headless regression
checks, and a disciplined documentation system. What it lacks is a **game-making
layer**: reusable instructions for the decisions that are specific to making a
game — design shaping, Godot prototyping, game feel, evidence-based playtesting,
art direction, and scope control.

The harness should be reusable for a future project, but ship configured for
GENESIS by default. It must reduce the chance that an agent invents conventions,
skips the playable evidence, or grows scope.

## Goals

- Give agents six focused, discoverable skills for the game-development loop.
- Put project defaults (engine version, commands, paths, doc statuses) in one
  profile file so a new game only needs a new profile.
- Provide slash commands that start the right workflow without the owner
  remembering skill names.
- Make the harness itself verifiable: a script fails when the harness is
  incomplete or inconsistent.
- Keep the existing Superpowers install untouched.

## Non-goals

- A plugin, server, or framework.
- Replacing `tools/verify.ps1` or the Godot test suite.
- Automating creative judgement, art approval, or milestone PASS decisions.
- Supporting multiple engines in the first version.
- Editing `vendor/superpowers/`.

## Anti-goals

- A single mega-skill that must be loaded for every task.
- Duplicating `game/README.md`, `AGENTS.md`, or the design docs wholesale.
- Skills that claim a check passed without running it.
- Skills that promote exploration (Muse output) into approved design.

## Constraints

- Godot 4.7.2 is required; the engine is not on this machine's `PATH`, so every
  command that needs it must accept an explicit executable path.
- The project is Windows-first for the owner but the commands must stay
  runnable from a POSIX shell; document both where cheap.
- OpenCode V2 discovers project skills in `.opencode/skills/` and, for
  compatibility, `.agents/skills/`. Codex discovers `.agents/skills/`.
  Using `.agents/skills/` serves both.
- Commands live in `.opencode/commands/<name>.md` (plural; V1 `command/` is
  still discovered but new files use the plural).
- Verified facts only: the harness may point at evidence, never invent it.
- Decision status vocabulary is fixed: **Confirmed**, **Proposed**, **Open**,
  **Risk**. Creative vocabulary: Exploration, Shortlisted, Candidate,
  Approved direction, Superseded.

## Approaches considered

1. **One `game-dev` mega-skill with reference files.** Few files, but the
   description must cover six disciplines, so it triggers weakly and loads a
   large body for narrow tasks. Rejected.
2. **Six focused skills + one project profile + commands + a validator.**
   Slightly more files, but each skill triggers on its own vocabulary and the
   profile keeps GENESIS facts in one place. Chosen.
3. **Plugin with hooks and custom tools.** Would enforce gates automatically,
   but the value does not justify the maintenance and debugging cost for a solo
   project. Rejected; revisit only if the skills are ignored in practice.

## Architecture

```text
harness/
  README.md                 How the harness works, how to add a skill or command
  project.md                Default project profile (GENESIS facts and commands)
  templates/
    design-brief.md         Short design shape with decision statuses
    playtest-report.md      Observation → criteria → verdict
    milestone-verdict.md    PASS / REVISE / BLOCKED record
    art-brief.md            Muse brief shape and review criteria
  scripts/
    check.ps1               Structural validator; exits non-zero on any failure
    evidence.ps1            Runs tools/verify.ps1 and writes a timestamped report
.agents/skills/
  game-design/SKILL.md      Shape an idea into an approved design
  game-build/SKILL.md       Smallest playable Godot implementation, test-first
  game-feel/SKILL.md        Measure and tune feel with playtest evidence
  game-verify/SKILL.md      Run verification, capture evidence, record a verdict
  game-art/SKILL.md         Write Muse briefs, review outputs, protect direction
  game-scope/SKILL.md       Cut scope toward the vertical slice
.opencode/commands/
  game-design.md  game-build.md  game-verify.md
  game-feel.md    game-art.md    game-scope.md
```

**Profile is authoritative for defaults.** Every skill starts by reading
`harness/project.md`. When the file is missing, the skill asks for the project
facts instead of guessing. A future game copies `harness/` and rewrites
`project.md`; the skills stay unchanged.

**No duplicated truth.** Skills point to `AGENTS.md`, `game/README.md`,
`docs/MILESTONES.md` and `creative/muse/README.md` for rules and commands
already documented there. The profile carries only the pointers and the
values an agent needs before opening those files.

## Skill contracts

Each skill states when it applies, a short workflow, the evidence it must
produce, and what it must not do. Shared rules: read the profile first, honour
the brainstorming/planning gates, run real commands instead of asserting
success, and keep decision statuses intact.

| Skill | Trigger examples | Required output |
|---|---|---|
| `game-design` | "design a mechanic", "new region", "is this worth building" | Design doc with approaches, statuses, explicit non-goals |
| `game-build` | "implement", "prototype this", "add the mechanic" | Failing check first, smallest change, headless check, playable scene |
| `game-feel` | "feels floaty", "tune movement", "juice" | Measured values, before/after playtest criteria, tuned constants |
| `game-verify` | "verify", "is it done", "milestone check" | Command output summary, evidence paths, PASS/REVISE/BLOCKED |
| `game-art` | "Muse brief", "review these concepts", "art direction" | Brief in the Muse workspace, review table, statuses unchanged unless approved |
| `game-scope` | "scope", "cut", "is this MVP" | Value/cost/defer table, recommendation, updated scope docs |

## Commands

`/game-design <topic>`, `/game-build <task>`, `/game-verify [milestone]`,
`/game-feel <area>`, `/game-art <brief>`, `/game-scope <proposal>`.

Each command is a short prompt that names the skill and the profile, and then
passes the argument through. Commands must not contain shell interpolation of
untrusted arguments.

## Harness verification

`harness/scripts/check.ps1` is the harness's own test. It fails when:

- a skill directory lacks `SKILL.md` or its `name`/`description` frontmatter;
- a skill does not reference `harness/project.md`;
- a command file names a missing skill or lacks a `description`;
- `harness/project.md` is missing or omits a required section;
- a referenced repository path does not exist;
- a template or script named in the README is missing.

It exits 0 with a per-check summary and non-zero on any failure, matching the
`tools/verify.ps1` contract. `evidence.ps1` runs the game verification only;
the harness never fakes a Godot pass.

## Phasing

1. **P1 — Profile and design loop:** `harness/project.md`, `harness/README.md`,
   `check.ps1`, `game-design`, `/game-design`.
2. **P2 — Build and verify loop:** `game-build`, `game-verify`,
   `evidence.ps1`, `/game-build`, `/game-verify`.
3. **P3 — Feel, art, scope:** `game-feel`, `game-art`, `game-scope`,
   templates, matching commands.
4. **P4 — Wiring:** README/AGENTS.md pointers, full validator run, docs update.

Each phase leaves the repository in a usable state.

## Risks / open items

- **Cost of discovery:** six descriptions can crowd the skill list. Mitigation:
  distinct, game-specific descriptions; merge if one never triggers.
- **Duplication drift:** profile values can go stale. Mitigation: the profile
  points to sources and `check.ps1` verifies referenced paths; a milestone
  review re-reads the profile.
- **OpenCode vs Codex commands:** commands are OpenCode-native. Codex users
  still get the skills; commands are convenience only.
- **Validator scope:** `check.ps1` proves structure, not usefulness. Skill
  quality is reviewed after the first real use.
