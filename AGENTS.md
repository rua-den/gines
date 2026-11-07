# Agent Instructions — GENESIS

## Project context

Before making changes, read:
- `README.md`
- `docs/GAME_DESIGN_FOUNDATION.md`
- `docs/DEVELOPMENT_PLAN.md`
- `docs/BACKLOG.md`

These documents are the project source of truth. Preserve the distinction between **Confirmed**, **Proposed**, **Open**, and **Risk** decisions. Do not silently turn proposals into requirements.

## Superpowers workflow

This repository contains a local copy of the official [obra/superpowers](https://github.com/obra/superpowers) skills under `vendor/superpowers/skills/`. Its skills are exposed through repo-local entries in `.agents/skills/`. No submodule initialization or separate pull is required.

- At the start of a task, activate and follow the `using-superpowers` skill when it is available.
- For new features or substantial design changes: use `brainstorming` first, agree on the design, then write or update an implementation plan.
- Before implementation: use `writing-plans` and break work into small, verifiable tasks.
- For code changes: use `test-driven-development` (write a failing test, implement the smallest change, make it pass, then refactor).
- For bugs: use `systematic-debugging`; reproduce first, investigate the root cause, and add a regression test.
- During implementation: use `executing-plans` or `subagent-driven-development` as appropriate, verifying each task.
- Before declaring work complete: use `verification-before-completion` and the relevant review skill.
- Do not skip a workflow step merely to move faster. If a step is genuinely inapplicable, state why briefly.
- Do not edit vendored upstream skills in place. Add GENESIS-specific guidance here or create a clearly named project skill instead.

## GENESIS-specific engineering rules

- Prototype the smallest playable loop before building broad content.
- Prioritize movement, survival/absorption, and the first meaningful evolution.
- Keep gameplay systems data-driven where that reduces iteration cost, but avoid premature frameworks.
- Keep biological inspiration readable and coherent without turning the game into a simulation.
- Protect progression from softlocks: evolution/build choices must not make required content impossible.
- Prefer small, reversible changes. Do not introduce dependencies or large architectural systems without explaining their value.
- Every milestone must have observable acceptance criteria and a runnable verification path.
- Do not claim a build, test, or workflow passed unless it was actually run and its result observed.

## Solo-development scope guard

Optimize for a finished, compelling vertical slice—not maximum feature count. When scope grows, identify the player-facing value, implementation cost, and what should be deferred. Surface blockers with evidence and attempt bounded recovery before stopping.
