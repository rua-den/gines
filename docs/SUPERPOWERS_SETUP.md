# Superpowers Setup & Workflow

## Included directly in this repository

GENESIS contains a local copy of the official [obra/superpowers](https://github.com/obra/superpowers) skill library under `vendor/superpowers/`. The included source is pinned to upstream commit `22f0b463e7a5e579904dd6211a520321035526f7`.

The complete upstream `skills/` directory, its supporting prompts/references/scripts, the upstream README, and MIT license are committed as ordinary files. Fifteen skills are exposed to Codex through repo-local links in `.agents/skills/`.

**No Git submodule, separate clone, init command, or recurring pull is required.** A normal clone of GENESIS includes the vendored skill files.

## Use in Codex

1. Clone or open the GENESIS repository normally.
2. Open the repository root in Codex.
3. Start a new session if the skills are not discovered immediately.
4. The agent should activate `using-superpowers` and follow the relevant workflow skill for the task.

The skill links point into `vendor/superpowers/skills/`; keep both directories together when moving or copying the project.

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

## Updating the vendored copy

When intentionally updating Superpowers, review the upstream changes and copy the updated `skills/` tree and its supporting files into `vendor/superpowers/`. Then update the pinned upstream commit in this document and commit the changes to GENESIS. Updates are manual and deliberate; the project will not change just because upstream changes.

## License

The upstream MIT license is included at `vendor/superpowers/LICENSE`.
