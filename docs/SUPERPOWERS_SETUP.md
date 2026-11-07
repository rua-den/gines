# Superpowers Setup & Workflow

## What this adds

GENESIS uses [obra/superpowers](https://github.com/obra/superpowers), an agentic skills framework and software-development methodology. It provides reusable workflows for brainstorming, planning, test-driven development, debugging, execution, and review.

The repository-level rules live in `/AGENTS.md`. The actual Superpowers skill package is installed into the coding-agent environment; it is intentionally not copied or vendored into this repository.

## Install in Codex

Superpowers is distributed through the Codex plugin marketplace:

1. Open the Codex app's **Plugins** section (or run `/plugins` in Codex CLI).
2. Search for **Superpowers**.
3. Select **Install Plugin**.
4. Restart/reload the Codex session if the skills are not discovered immediately.

Official project and installation instructions: https://github.com/obra/superpowers

> Installing the plugin in Codex is a user/environment-level action. Committing `AGENTS.md` makes the GENESIS-specific workflow persistent in the repo, but does not itself install the plugin on every developer's machine.

## Expected workflow for GENESIS

1. **Understand** — read the project docs and identify confirmed decisions, open questions, and scope risks.
2. **Brainstorm** — use the brainstorming skill for new mechanics, systems, or significant changes; agree on a design before coding.
3. **Plan** — write a concrete implementation plan with small tasks, dependencies, and acceptance criteria.
4. **Test first** — add or update tests before implementation wherever practical.
5. **Implement** — make the smallest coherent change; verify each task before moving on.
6. **Review** — inspect the diff for correctness, scope creep, regressions, and maintainability.
7. **Report** — state what changed, what was verified, and what remains open. Never imply unrun checks passed.

## Scope and recovery rules

- Prefer a working playable prototype over speculative architecture.
- Keep the first prototype focused on player movement, survival/absorption, and one evolution milestone.
- When a tool or test fails, diagnose and attempt bounded recovery; do not treat the first failure as a terminal blocker.
- Stop only for a real external blocker, a required user decision, or a documented quality/safety gate.
