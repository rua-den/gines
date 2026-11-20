---
name: Game Verify
description: Verify a milestone, feature or build with observed evidence and record a PASS/REVISE/BLOCKED verdict. Use when asked "is it done", "verify", "check the milestone", or before reporting completion.
---

# Game Verify

Evidence before claims. A green impression is not a green run.

## First

1. Read `harness/project.md` for the verification commands and engine path
   rules.
2. Read the milestone's observable criteria in `docs/MILESTONES.md` and
   `docs/BACKLOG.md`. Name the milestone and the criteria before running
   anything.
3. Load the `verification-before-completion` skill.

## Workflow

1. **Run the gate.** From the repository root:

   ```powershell
   pwsh -File harness/scripts/evidence.ps1 -Godot "<path to Godot 4.7.2>"
   ```

   Add `-SkipDemo` only when there is no display, and say so in the verdict.
   The script runs `tools/verify.ps1`, writes a timestamped report, and exits
   with the verification exit code.
2. **Read the report.** List each check and its observed result. Do not
   summarize a failure as "mostly green".
3. **Match evidence to criteria.** For each criterion: which command or
   capture proves it? An automated check cannot prove a human feel criterion.
4. **Separate the two kinds of acceptance.** Automated checks (tests, smoke,
   demo autopilot) and human checks (does it feel right, is it understandable,
   is it fun). Record human checks as **open** until the owner does them.
5. **Record the verdict** in `docs/MILESTONES.md` using
   `harness/templates/milestone-verdict.md`: **PASS**, **REVISE** or
   **BLOCKED**, with commands, evidence paths and rationale.
6. **Report honestly** what was not run and why.

## Verdict rules

- **PASS** — every criterion has observed evidence, including the owner's
  human check where the criterion is a feel or comprehension judgement.
- **REVISE** — the work runs but a criterion fails or the feel is wrong.
- **BLOCKED** — the check cannot run (missing engine, missing scene, broken
  prerequisite). Never convert blocked into pass.

## Must not

- Mark PASS from a headless-only run when screenshots or feel are required.
- Reuse an older report as if it were this build's evidence.
- Hide a failing check, or report a subset as the whole suite.
- Change the criteria to match the result.
