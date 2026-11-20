---
description: Verify a build or milestone and record a verdict
---

Load the `game-verify` skill and read `harness/project.md` first.

Verify: $ARGUMENTS

Run `harness/scripts/evidence.ps1` with the project's engine path, read the
report, match evidence to criteria in `docs/MILESTONES.md`, and record
PASS/REVISE/BLOCKED with the commands and evidence paths. Keep human feel
checks open until the owner does them.
