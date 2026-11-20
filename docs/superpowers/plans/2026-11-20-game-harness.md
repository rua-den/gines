# GENESIS Game Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable, GENESIS-configured game-development harness: six agent skills, six slash commands, a project profile, templates, and a validator that fails when the harness is incomplete.

**Architecture:** A `harness/` directory holds the project profile, templates, and two PowerShell scripts. Skills live as real directories in `.agents/skills/` (visible to both Codex and OpenCode); commands live in `.opencode/commands/`. Every skill reads `harness/project.md` first, then points at the existing documentation instead of copying it.

**Tech Stack:** Markdown skill/command files, PowerShell 7 scripts, Godot 4.7.2 commands (invoked only through the existing verification tooling).

**Spec:** `docs/superpowers/specs/2026-11-20-game-harness-design.md`

## Global Constraints

- Do not modify `vendor/superpowers/` or the 15 existing symlinks in `.agents/skills/`.
- Decision statuses: **Confirmed**, **Proposed**, **Open**, **Risk**. Creative statuses: Exploration, Shortlisted, Candidate, Approved direction, Superseded.
- Engine facts: Godot 4.7.2 stable only; project path `game/`; base viewport 960×540; `gl_compatibility`; input actions are snake_case and defined in `project.godot`.
- A check may only claim PASS after its command was run and its output observed.
- Harness scripts must exit non-zero on failure, matching `tools/verify.ps1`.
- No secrets, no absolute machine paths in committed files.
- File names: `snake_case` for scripts; skill directories lowercase kebab-case.

## Review Focus

- **Missing profile:** a skill loaded in a repository without `harness/project.md` must ask for the facts, never fall back to invented engine versions or paths.
- **Stale profile:** referenced paths must be checked by `check.ps1`, so a moved doc fails the harness instead of silently misdirecting an agent.
- **Command/skill mismatch:** a command that names a missing skill must fail `check.ps1`.
- **Unverified claim:** `evidence.ps1` must propagate `tools/verify.ps1`'s exit code and never print PASS when Godot is missing.
- **Status leakage:** skills and templates must not label exploration as approved or a proposal as confirmed.

---

### Task 1: Profile, README, and structural validator

**Files:**
- Create: `harness/project.md`
- Create: `harness/README.md`
- Create: `harness/scripts/check.ps1`

**Interfaces:**
- Produces: `harness/scripts/check.ps1` — exits 0 only when all structural checks pass; prints one `[PASS]`/`[FAIL]` line per check and a `HARNESS CHECK PASSED|FAILED` summary.
- Produces: `harness/project.md` with the exact headings `## Project`, `## Engine`, `## Commands`, `## Repository map`, `## Decision rules`, `## Scope guard`, `## Creative`, `## Sources`.

- [ ] **Step 1: Write the validator first**

Create `harness/scripts/check.ps1`:

```powershell
# GENESIS game harness — structural check.
# Exits 0 only when every harness file is present and internally consistent.
# Usage: pwsh -File harness/scripts/check.ps1

[CmdletBinding()]
param()

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$results = [System.Collections.Generic.List[object]]::new()
$failed = 0

function Add-Check {
    param([string]$Name, [bool]$Ok, [string]$Detail = "")
    $script:results.Add([pscustomobject]@{ Name = $Name; Passed = $Ok })
    if (-not $Ok) { $script:failed++ }
    $label = if ($Ok) { "PASS" } else { "FAIL" }
    Write-Host ("[{0}] {1}" -f $label, $Name)
    if (-not $Ok -and $Detail -ne "") { Write-Host "      $Detail" }
}

function Test-PathRelative {
    param([string]$Relative)
    Test-Path -LiteralPath (Join-Path $root $Relative)
}

$requiredPaths = @(
    "harness/project.md",
    "harness/README.md",
    "harness/scripts/check.ps1",
    "harness/scripts/evidence.ps1",
    "harness/templates/design-brief.md",
    "harness/templates/playtest-report.md",
    "harness/templates/milestone-verdict.md",
    "harness/templates/art-brief.md",
    "AGENTS.md",
    "game/README.md",
    "tools/verify.ps1",
    "docs/GAME_DESIGN_FOUNDATION.md",
    "docs/DEVELOPMENT_PLAN.md",
    "docs/MILESTONES.md",
    "docs/BACKLOG.md",
    "creative/muse/README.md"
)
foreach ($p in $requiredPaths) {
    Add-Check "file: $p" (Test-PathRelative $p) "missing $p"
}

$skillIds = @("game-design", "game-build", "game-feel", "game-verify", "game-art", "game-scope")
foreach ($id in $skillIds) {
    $file = "harness/../.agents/skills/$id/SKILL.md"
    $full = Join-Path $root ".agents/skills/$id/SKILL.md"
    $exists = Test-Path -LiteralPath $full
    Add-Check "skill file: $id" $exists "missing .agents/skills/$id/SKILL.md"
    if ($exists) {
        $text = Get-Content -Raw -LiteralPath $full
        Add-Check "skill frontmatter: $id" ($text -match '(?m)^name:\s*\S+' -and $text -match '(?m)^description:\s*\S+') "needs name: and description: frontmatter"
        Add-Check "skill reads profile: $id" ($text -match 'harness/project\.md') "must reference harness/project.md"
    }
}

$profile = Join-Path $root "harness/project.md"
if (Test-Path -LiteralPath $profile) {
    $text = Get-Content -Raw -LiteralPath $profile
    $headings = @("## Project", "## Engine", "## Commands", "## Repository map", "## Decision rules", "## Scope guard", "## Creative", "## Sources")
    foreach ($h in $headings) {
        Add-Check "profile heading: $h" ($text -match [regex]::Escape($h)) "missing heading $h"
    }
}

$commandDir = Join-Path $root ".opencode/commands"
$expectedCommands = @("game-design", "game-build", "game-verify", "game-feel", "game-art", "game-scope")
foreach ($c in $expectedCommands) {
    $file = Join-Path $commandDir "$c.md"
    $exists = Test-Path -LiteralPath $file
    Add-Check "command: /$c" $exists "missing .opencode/commands/$c.md"
    if ($exists) {
        $text = Get-Content -Raw -LiteralPath $file
        Add-Check "command description: /$c" ($text -match '(?m)^description:\s*\S+') "needs description: frontmatter"
        $namedSkill = $text -match "(?<![a-z-])$c(?![a-z-])"
        $skillExists = Test-Path -LiteralPath (Join-Path $root ".agents/skills/$c/SKILL.md")
        Add-Check "command maps to skill: /$c" ($namedSkill -and $skillExists) "must name skill $c and that skill must exist"
    }
}

Write-Host ""
if ($failed -gt 0) {
    Write-Host ("HARNESS CHECK FAILED: {0} of {1} checks failed" -f $failed, $results.Count) -ForegroundColor Red
    exit 1
}
Write-Host ("HARNESS CHECK PASSED: {0} checks" -f $results.Count) -ForegroundColor Green
exit 0
```

- [ ] **Step 2: Run it to verify it fails**

Run: `pwsh -File harness/scripts/check.ps1`
Expected: exit 1, `HARNESS CHECK FAILED`, failures for the missing profile, README, scripts, templates, skills, and commands.

- [ ] **Step 3: Write `harness/project.md`**

Content must include, under the eight required headings: project name and genre; engine and version; run/verify commands with the `-Godot` parameter; the repository map (`game/`, `docs/`, `creative/muse/`, `tools/verify.ps1`); the four decision statuses plus creative statuses; the scope guard (vertical slice first, defer list); Muse rules (outputs under `creative/muse/outputs/`, concept IDs, exploration until approved); and the source list (AGENTS.md, README.md, game/README.md, docs/*.md, creative/muse/README.md). Keep it to the facts an agent needs before opening those files, with pointers for detail.

- [ ] **Step 4: Write `harness/README.md`**

Explain: what the harness is, the six skills and when each fires, the six commands, how a skill uses `harness/project.md`, how to run `check.ps1` and `evidence.ps1`, how to port the harness to another game (copy `harness/` plus skill dirs, rewrite `project.md`), and the rule that the harness never approves creative or milestone decisions.

- [ ] **Step 5: Run the validator**

Run: `pwsh -File harness/scripts/check.ps1`
Expected: still exit 1, but only for the not-yet-created evidence script, templates, skills, and commands.

- [ ] **Step 6: Commit**

```bash
git add harness docs/superpowers/specs/2026-11-20-game-harness-design.md docs/superpowers/plans/2026-11-20-game-harness.md
git commit -m "feat(harness): add game project profile, readme and structural check"
```

---

### Task 2: Design skill and command

**Files:**
- Create: `.agents/skills/game-design/SKILL.md`
- Create: `.opencode/commands/game-design.md`

**Interfaces:**
- Consumes: `harness/project.md`; the brainstorming and writing-plans gates in `.agents/skills/`.
- Produces: `/game-design` command naming skill `game-design`; design docs in `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.

- [ ] **Step 1: Write the skill**

Frontmatter: `name: Game Design`, a `description` naming triggers (new mechanic, region, evolution branch, "is this worth building", design change) and stating it produces a decision-ready design doc. Body: read `harness/project.md`; check `docs/GAME_DESIGN_FOUNDATION.md`, `docs/DEVELOPMENT_PLAN.md`, `docs/BACKLOG.md` for existing decisions; invoke `brainstorming` for anything non-trivial; explore before asking; present 2–3 concrete approaches with trade-offs and a recommendation; write the design using `harness/templates/design-brief.md`; label every decision Confirmed/Proposed/Open/Risk; list non-goals and anti-goals; protect required progression (no softlocks); hand off to `writing-plans` only after owner approval. Include a "must not" list: invent owner approval, promote Muse concepts, skip the prototype gate, copy design docs wholesale.

- [ ] **Step 2: Write the command**

`.opencode/commands/game-design.md` with `description:` frontmatter and body: load skill `game-design`, read `harness/project.md`, then shape `$ARGUMENTS` into an approved design; ask for approval before implementation.

- [ ] **Step 3: Run the validator**

Run: `pwsh -File harness/scripts/check.ps1`
Expected: skill and command checks PASS; remaining failures only for Task 3–4 artifacts.

- [ ] **Step 4: Commit**

```bash
git add .agents/skills/game-design .opencode/commands/game-design.md
git commit -m "feat(harness): add game-design skill and command"
```

---

### Task 3: Build, verify, and evidence script

**Files:**
- Create: `.agents/skills/game-build/SKILL.md`
- Create: `.agents/skills/game-verify/SKILL.md`
- Create: `.opencode/commands/game-build.md`
- Create: `.opencode/commands/game-verify.md`
- Create: `harness/scripts/evidence.ps1`

**Interfaces:**
- Consumes: `tools/verify.ps1 -Godot <path> [-SkipDemo] [-OutDir <dir>]`, exit 0 on pass.
- Produces: `harness/scripts/evidence.ps1 -Godot <path> [-SkipDemo] [-OutFile <path>]`; propagates the verify exit code; default report `.superpowers/reports/verify-<yyyyMMdd-HHmmss>.md`.

- [ ] **Step 1: Write `game-build`**

Body: read profile; invoke `test-driven-development`; find the failing headless check first (or write one in `game/tests/`), run it, implement the smallest change, re-run, then run the scene smoke check; follow `game/README.md` naming, input-action, resolution and renderer rules; keep changes reversible; do not add dependencies, autoloads, or frameworks without a recorded reason; do not touch `vendor/`; report exact commands and outputs.

- [ ] **Step 2: Write `game-verify`**

Body: read profile; determine the milestone from `docs/MILESTONES.md` / `docs/BACKLOG.md`; run `harness/scripts/evidence.ps1 -Godot <path>` (add `-SkipDemo` only when no display and say so); read the report; compare against the milestone's observable criteria; record **PASS / REVISE / BLOCKED** using `harness/templates/milestone-verdict.md`; never mark PASS from a headless-only run when criteria need a human feel check; state the human checks still open.

- [ ] **Step 3: Write `evidence.ps1`**

Implementation requirements: resolve `$root` from `$PSScriptRoot`; default `-OutFile` to `.superpowers/reports/verify-<timestamp>.md`, creating the directory; run `pwsh -NoProfile -File tools/verify.ps1 -Godot $Godot` with `-SkipDemo` and `-OutDir` forwarded when provided; `Tee-Object` the output to the report and the console; preserve `$LASTEXITCODE`; append a header with timestamp, Godot path, arguments, and the final verdict line; exit with the verify exit code. Missing `-Godot` follows verify's own preflight failure.

- [ ] **Step 4: Write the two commands**

`game-build.md` and `game-verify.md`, each with `description:` and body naming its skill, the profile, and `$ARGUMENTS` (verify: optional milestone name).

- [ ] **Step 5: Test the evidence script's failure path**

Run: `pwsh -File harness/scripts/evidence.ps1 -Godot "definitely-not-godot" -SkipDemo`
Expected: exit 1, report written, report contains `VERIFY FAILED` (from verify's preflight) and the header. This proves the script cannot report success without an engine.

- [ ] **Step 6: Run the validator**

Run: `pwsh -File harness/scripts/check.ps1`
Expected: build/verify/evidence checks PASS.

- [ ] **Step 7: Commit**

```bash
git add .agents/skills/game-build .agents/skills/game-verify .opencode/commands/game-build.md .opencode/commands/game-verify.md harness/scripts/evidence.ps1
git commit -m "feat(harness): add game-build, game-verify and evidence runner"
```

---

### Task 4: Feel, art, scope skills, templates, commands

**Files:**
- Create: `.agents/skills/game-feel/SKILL.md`
- Create: `.agents/skills/game-art/SKILL.md`
- Create: `.agents/skills/game-scope/SKILL.md`
- Create: `harness/templates/design-brief.md`
- Create: `harness/templates/playtest-report.md`
- Create: `harness/templates/milestone-verdict.md`
- Create: `harness/templates/art-brief.md`
- Create: `.opencode/commands/game-feel.md`
- Create: `.opencode/commands/game-art.md`
- Create: `.opencode/commands/game-scope.md`

**Interfaces:**
- Consumes: `harness/project.md`, `creative/muse/README.md`, `docs/CREATIVE_EXPLORATION_PLAN.md`, `docs/MILESTONES.md`.
- Produces: templates referenced by the skills and by `harness/README.md`.

- [ ] **Step 1: Write `game-feel`**

Workflow: name the felt problem in player terms; identify the measurable inputs (acceleration, max speed, friction, camera smoothing, feedback delay, hitstop, telegraph); propose 2–3 parameter sets with expected feel trade-offs; run or request a playtest with explicit pass/fail statements; record before/after values and the evidence path; mark tuned values **Proposed** until the owner confirms. Must not tune by intuition without a playtest note, and must not gate required progression on feel changes.

- [ ] **Step 2: Write `game-art`**

Workflow: read `creative/muse/README.md` and the current direction; write the brief with `harness/templates/art-brief.md` (intent, constraints, silhouettes, palette, animation budget, acceptance); save outputs under the documented category folder with a concept ID; review against gameplay value, consistency, emotional impact, and solo-production cost; keep statuses Exploration/Shortlisted/Candidate unless the owner approves; never imitate a named game's style or assets.

- [ ] **Step 3: Write `game-scope`**

Workflow: restate the proposal's player-facing value, implementation cost, and dependency; classify as keep / defer / cut; check it against the vertical-slice gate and the "explicitly out of scope" list in `docs/BACKLOG.md`; produce a short table plus a recommendation; update docs only after owner agreement; never silently turn a proposal into a requirement.

- [ ] **Step 4: Write the four templates**

- `design-brief.md`: problem, player value, approaches + trade-offs, chosen approach, decisions by status, non-goals, acceptance, risks.
- `playtest-report.md`: build/commit, scenario, what the player did, what was observed, criteria and result, feel notes, next action.
- `milestone-verdict.md`: milestone, claims checked, commands run with results, evidence paths, human checks open, verdict PASS/REVISE/BLOCKED, rationale.
- `art-brief.md`: intent, gameplay/emotional purpose, constraints (960×540, 2D frame-by-frame budget), composition/silhouette, palette, references allowed (no style imitation), deliverables, review criteria.

- [ ] **Step 5: Write the three commands**

Each with `description:` and a body naming its skill, the profile, and `$ARGUMENTS`.

- [ ] **Step 6: Run the validator**

Run: `pwsh -File harness/scripts/check.ps1`
Expected: `HARNESS CHECK PASSED` with every check PASS.

- [ ] **Step 7: Commit**

```bash
git add .agents/skills/game-feel .agents/skills/game-art .agents/skills/game-scope harness/templates .opencode/commands
git commit -m "feat(harness): add feel, art and scope skills with templates"
```

---

### Task 5: Wire the harness into the repository docs and verify end to end

**Files:**
- Modify: `README.md` (Documentation list)
- Modify: `AGENTS.md` (add a short Game harness section)
- Modify: `harness/README.md` if Task 1 left anything inaccurate

- [ ] **Step 1: Add the documentation pointer**

In `README.md`, add a bullet linking `harness/README.md` as the game-making harness (skills, commands, profile, validator).

- [ ] **Step 2: Add the agent rule**

In `AGENTS.md`, add a short section: read `harness/project.md` before game work; use the matching game skill; run `harness/scripts/check.ps1` after changing the harness; the harness never approves designs, art, or milestones. Do not restate the six skills.

- [ ] **Step 3: Run the full harness check**

Run: `pwsh -File harness/scripts/check.ps1`
Expected: `HARNESS CHECK PASSED`.

- [ ] **Step 4: Verify the game toolchain is untouched**

Run: `pwsh -File tools/verify.ps1 -Godot "definitely-not-godot" -SkipDemo`
Expected: exit 1 with `Cannot find the Godot executable` — proves the existing gate still fails closed and the harness did not alter it.

- [ ] **Step 5: Review the diff**

Run: `git status --short; git diff --stat`
Expected: only harness files, skill/command files, two docs, and the design/plan docs. No changes under `vendor/`, `game/`, or `creative/`.

- [ ] **Step 6: Commit**

```bash
git add README.md AGENTS.md harness
git commit -m "docs(harness): wire game harness into repository guidance"
```

---

## Self-review notes

- Spec coverage: P1 → Tasks 1–2; P2 → Task 3; P3 → Task 4; P4 → Task 5. The validator covers every "harness verification" bullet except usefulness, which is explicitly left to review after first use.
- Failure-path tests exist for the two scripts (missing Godot) and for structural gaps (validator before files exist).
- No task claims a Godot run passes on this machine; the engine is absent and the plan only asserts failure-path behavior.
