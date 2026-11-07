# Superpowers Setup & Workflow

## Included in this repository

GENESIS vendors the official [obra/superpowers](https://github.com/obra/superpowers) repository as a Git submodule at `vendor/superpowers`. The upstream version is pinned to commit `22f0b463e7a5e579904dd6211a520321035526f7`.

Fifteen upstream skills are exposed to Codex through repo-local skill links in `.agents/skills/`. Codex discovers project skills from this directory, so they are available when Codex opens the repository (after the submodule is initialized).

## Clone / initialize

Clone with submodules:

```bash
git clone --recurse-submodules https://github.com/rua-den/gines.git
```

If the repository was already cloned without submodules:

```bash
git submodule update --init --recursive
```

Then open the repository root in Codex. If the skills do not appear immediately, restart the Codex session.

> The skills are repo-scoped: this makes them available inside GENESIS without installing them globally for every project. The repository itself contains the submodule reference and skill links; Git must initialize the submodule to populate the actual upstream skill files.

## Included upstream skills

- `using-superpowers`
- `brainstorming`
- `writing-plans`
- `test-driven-development`
- `systematic-debugging`
- `executing-plans`
- `subagent-driven-development`
- `dispatching-parallel-agents`
- `verification-before-completion`
- `requesting-code-review`
- `receiving-code-review`
- `finishing-a-development-branch`
- `using-git-worktrees`
- `writing-skills`
- `diagnosing-superpowers`

## Expected workflow for GENESIS

1. **Understand** — read the project docs and identify confirmed decisions, open questions, and scope risks.
2. **Bootstrap** — follow `using-superpowers` and select the relevant skill(s).
3. **Brainstorm** — use the brainstorming skill for new mechanics, systems, or significant changes; agree on a design before coding.
4. **Plan** — write a concrete implementation plan with small tasks, dependencies, and acceptance criteria.
5. **Test first** — add or update tests before implementation wherever practical.
6. **Implement** — make the smallest coherent change; verify each task before moving on.
7. **Review** — inspect the diff for correctness, scope creep, regressions, and maintainability.
8. **Report** — state what changed, what was verified, and what remains open. Never imply unrun checks passed.

## Updating upstream

To update the pinned Superpowers version intentionally:

```bash
git submodule update --remote vendor/superpowers
git add .gitmodules vendor/superpowers .agents/skills
git commit -m "chore: update Superpowers"
```

Review upstream changes before accepting an update. Do not blindly track upstream `main` in production work.

## Scope and recovery rules

- Prefer a working playable prototype over speculative architecture.
- Keep the first prototype focused on player movement, survival/absorption, and one evolution milestone.
- When a tool or test fails, diagnose and attempt bounded recovery; do not treat the first failure as a terminal blocker.
- Stop only for a real external blocker, a required user decision, or a documented quality/safety gate.

## License

Superpowers is distributed under the MIT License. See `vendor/superpowers/LICENSE` after initializing the submodule.
