# GENESIS Game Harness

A small, reusable layer for making games with an AI agent. Six focused skills
cover the game-development loop; a project profile supplies the defaults; six
slash commands are the entry points; one validator proves the harness itself is
complete.

**Default project:** GENESIS. Every skill reads
[`project.md`](project.md) first. To use the harness on another game, copy
`harness/` and `.agents/skills/game-*`, rewrite `project.md`, and leave the
skills unchanged.

## Quick start

```powershell
# Prove the harness is complete and internally consistent
pwsh -File harness/scripts/check.ps1

# Run the game's real verification and keep a report
pwsh -File harness/scripts/evidence.ps1 -Godot "C:\path\to\Godot_v4.7.2-stable_win64_console.exe"
```

In a session, use `/game-design`, `/game-build`, `/game-verify`, `/game-feel`,
`/game-art` or `/game-scope`. Without commands, load the skill by ID.

## Skills

| Skill | Use it when | Produces |
|---|---|---|
| `game-design` | shaping a mechanic, region, evolution branch or change | design doc with approaches, statuses, non-goals |
| `game-build` | implementing or prototyping in Godot | failing check first, smallest change, headless proof |
| `game-feel` | movement/combat feels wrong or needs tuning | measured values, playtest criteria, tuned constants |
| `game-verify` | asking "is it done?" or checking a milestone | command output, evidence paths, PASS/REVISE/BLOCKED |
| `game-art` | Muse brief, concept review, art direction | brief in the Muse workspace, review table, statuses |
| `game-scope` | scope is growing or a feature needs cutting | value/cost/defer table, recommendation |

Rules shared by all skills: read `project.md` first; follow the Superpowers
gates (`brainstorming` before new work, `writing-plans` before implementation,
`test-driven-development` for code, `verification-before-completion` before
claiming success); run real commands; keep decision statuses honest.

## Commands

`.opencode/commands/game-*.md` map one-to-one to the skills. Each template names
its skill, the profile, and passes `$ARGUMENTS` through. They are convenience
only; the skills work without them.

## Files

| Path | Responsibility |
|---|---|
| `project.md` | GENESIS facts and defaults: engine, commands, map, statuses, scope, Muse rules |
| `scripts/check.ps1` | structural validator; non-zero exit on any missing or inconsistent piece |
| `scripts/evidence.ps1` | runs `tools/verify.ps1`, writes a timestamped report, propagates the exit code |
| `templates/` | design brief, playtest report, milestone verdict, art brief |
| `../.agents/skills/game-*/` | the six skills (Codex and OpenCode both discover this path) |
| `../.opencode/commands/game-*.md` | the six slash commands |

## What the harness never does

- Approve a design, an art direction or a milestone. Only the project owner
  does, with evidence.
- Turn a **Proposed** or **Open** decision into **Confirmed**, or an
  exploration into "Approved direction".
- Report a verification PASS it did not observe, or use a headless run to
  stand in for a human feel check.
- Duplicate the design docs, `game/README.md` or `AGENTS.md`; it points at
  them.
- Touch `vendor/superpowers/` or the vendored skill links.

## Extending

1. Add the skill under `.agents/skills/<kebab-case-id>/SKILL.md` with `name:`
   and `description:` frontmatter and a reference to `harness/project.md`.
2. Add a matching command in `.opencode/commands/<same-id>.md` with a
   `description:` and the skill name in the body.
3. Add both IDs to `scripts/check.ps1`'s lists.
4. Run `pwsh -File harness/scripts/check.ps1` and expect
   `HARNESS CHECK PASSED`.
5. Update this README and, if the skill changes the workflow, `AGENTS.md`.

If a skill never triggers in real use, merge or delete it instead of keeping
dead instructions.
