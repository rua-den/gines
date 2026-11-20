# 8-Stage Map Set Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce eight reviewable design-only stage maps, a documented schema, a validator that can fail, and a review report with observed evidence.

**Architecture:** Data files under `docs/maps/` describe stages in a 1920×1080 design-only coordinate space. A single dependency-free PowerShell checker enforces the schema invariants across all eight files. Nothing is loaded by Godot; no `game/` file is touched. The review report is generated from the checker's actual output.

**Tech Stack:** JSON data files, PowerShell 7 validator, repo docs. No engine, no dependencies.

**Spec:** `docs/superpowers/specs/2026-11-21-eight-stage-map-set-design.md` (read alongside this plan; every design value is **Proposed**).

## Global Constraints

- Every map has `artifact_type: "design_only"`, `schema_version: 1`, `room.width = 1920`, `room.height = 1080`, `coordinate_space: "design_only"`.
- Every map has ≥2 `static_slab` obstacles with positive rectangles inside the room.
- Every map has exactly one `upgrade`, exactly one `boss`, one `shelter` checkpoint, one `resources` block with `model: "single_nutrition"` and `meter_count: 1`, and one `narrative` block with `mother_role` in `{guide_only, absent}`.
- `boss.kind` must be `hostile_organism`; the mother is never a boss.
- `engine_status` is per feature. Implemented whitelist: upgrades `surface_grip`, `crawl`, `absorption_channel`, `spike_ring`, `spike_burst`, `energy_pool`; bosses `rot_bloom`; obstacle kinds `static_slab` and `gate`. Every `planned` feature, including obstacles, names `fallback_until_implemented`.
- A boss's `gate_requires` may only name an upgrade owned by that stage or an earlier one; the checker rejects a gate on a future-stage upgrade.
- `stage_status` is derived: both upgrade and boss implemented → `implemented`; exactly one implemented → `partial`; neither → `planned`.
- Chain: stage 01 `entry_requires = null`; stage N `exit_unlocks = map(N+1)` and stage N+1 `entry_requires = "mapNN.boss_defeated"`; stage 08 `exit_unlocks = "birth"`.
- Upgrades are `permanent: true` and `additive: true`; every upgrade and boss states `softlock_fallback`.
- Do not modify `game/`, `docs/MILESTONES.md`, `docs/BACKLOG.md`, or any official design decision. No Godot loader.
- Run from the repository root. `pwsh -File tools/check_maps.ps1` must print `MAP CHECK PASSED` and exit 0; a broken fixture must produce named failures and exit 1.

## Review Focus

- **Missing or degenerate obstacles** — a map with no solid geometry must fail; pinned by a fixture with `obstacles: []`.
- **Broken progression chain** — a gap between `exit_unlocks` and the next `entry_requires` must fail; pinned by a fixture with a rewritten `exit_unlocks`.
- **Dishonest engine status** — a planned upgrade/boss marked `implemented`, or an implemented id not in the whitelist, must fail; pinned by fixtures that flip one field.
- **Maternal boss / second resource meter** — `boss.kind: mother` or `meter_count: 2` must fail; pinned by fixtures that change those fields.
- **Softlock silence** — an upgrade or boss without `softlock_fallback`, or a planned feature without `fallback_until_implemented`, must fail; pinned by a fixture that removes one field.
- **Reviewer reads stale claims** — `REVIEW.md` must quote the observed checker output, not a predicted one.

---

### Task 1: Schema document and the eight map files

**Files:**
- Create: `docs/maps/SCHEMA.md`
- Create: `docs/maps/map01.json` … `docs/maps/map08.json`

**Interfaces:**
- Consumes: design doc stage table, `DEVELOPMENT_PLAN.md` §§4/5/7, `MILESTONES.md` M1–M5.
- Produces: eight JSON files whose field names are the validator's input contract; `SCHEMA.md` documents exactly those fields.

- [ ] **Step 1: Write `docs/maps/SCHEMA.md`**
  Document `artifact_type`, `schema_version`, `id`, `stage`, `name`, `developmental_beat`, `plan_refs`, `room`, `obstacles[]`, `upgrade`, `boss`, `checkpoint`, `resources`, `narrative`, `progression`, `stage_status`, `status`; state the design-only coordinate space and the implemented-id whitelist. No implementation is implied.

- [ ] **Step 2: Write `map01.json` … `map08.json`**
  Follow the design doc's stage table exactly. Use the field contract from `SCHEMA.md`. Each map must satisfy every Global Constraint above. Names, bosses and numeric values stay **Proposed**.

- [ ] **Step 3: Verify the JSON parses**
  Run: `pwsh -Command "Get-ChildItem docs/maps/map*.json | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null; Write-Output ('OK ' + $_.Name) }"`
  Expected: eight `OK mapNN.json` lines, exit 0.

- [ ] **Step 4: Commit**
  `git add docs/maps && git commit -m "docs(maps): add eight design-only stage maps and schema"`

---

### Task 2: Validator, test-first

**Files:**
- Create: `tools/check_maps.ps1`
- Test fixtures: temporary directory outside the repo (git-ignored workspace), eight copies of the real maps with one field broken at a time.

**Interfaces:**
- Consumes: `docs/maps/map*.json` from Task 1; field contract from `SCHEMA.md`.
- Produces: `pwsh -File tools/check_maps.ps1 [-MapsDir <path>]` printing `MAP CHECK PASSED — 8 maps, N checks` or `[FAIL] <file>: <rule>` lines; exit 0/1.

- [ ] **Step 1: Create the negative fixtures and run before the checker exists**
  Copy the eight maps into a temp dir, then make one fixture per Review Focus bullet. Run: `pwsh -File tools/check_maps.ps1 -MapsDir <temp>`
  Expected: RED — file-not-found or unrecognised-command failure. This proves the test is not passing by accident.

- [ ] **Step 2: Implement `tools/check_maps.ps1`**
  One script, `-MapsDir` parameter defaulting to the repo's `docs/maps`. Collect failures instead of stopping at the first. Validate every Global Constraint; derive `stage_status`; check the eight-link chain; print one `[FAIL]` line per violation with file and rule name. Print the success line and exit 0 only when the failure list is empty; otherwise exit 1. Do not write to any file.

- [ ] **Step 3: Run the negative fixtures**
  Run: `pwsh -File tools/check_maps.ps1 -MapsDir <temp>` for each fixture.
  Expected: exit 1 and a named `[FAIL]` line matching the broken rule; no fixture silently passes.

- [ ] **Step 4: Run the real maps**
  Run: `pwsh -File tools/check_maps.ps1`
  Expected: `MAP CHECK PASSED — 8 maps, N checks`, exit 0.

- [ ] **Step 5: Commit**
  `git add tools/check_maps.ps1 && git commit -m "tools(maps): add failing-safe map set validator"`

---

### Task 3: Review report and final verification

**Files:**
- Create: `docs/maps/REVIEW.md`
- Modify: none else.

**Interfaces:**
- Consumes: checker output from Task 2 and the stage table from the design doc.
- Produces: a per-map review table (obstacles / upgrade / boss / plan alignment / softlock safety / engine honesty) plus the verbatim observed checker output and a short scope note.

- [ ] **Step 1: Write `docs/maps/REVIEW.md`**
  Include exactly the output observed in Task 2 Step 4, a per-map table for all eight stages, the negative-test result, and the statement that this is a design review and not a milestone PASS.

- [ ] **Step 2: Verify the harness is unchanged**
  Run: `pwsh -File harness/scripts/check.ps1`
  Expected: `HARNESS CHECK PASSED`.

- [ ] **Step 3: Confirm no game files changed**
  Run: `git status --short`
  Expected: only `docs/maps/`, `tools/check_maps.ps1` and the two `docs/superpowers/` design/plan files appear.

- [ ] **Step 4: Commit**
  `git add docs/maps/REVIEW.md && git commit -m "docs(maps): review the eight-stage map set"`

---

## Verification summary

| Command | Expected |
|---|---|
| `pwsh -Command "...ConvertFrom-Json..."` | 8 `OK mapNN.json` lines |
| `pwsh -File tools/check_maps.ps1 -MapsDir <broken fixture>` | exit 1, named `[FAIL]` line |
| `pwsh -File tools/check_maps.ps1` | `MAP CHECK PASSED — 8 maps, N checks`, exit 0 |
| `pwsh -File harness/scripts/check.ps1` | `HARNESS CHECK PASSED` |
| `git status --short` | no `game/` changes |

This plan produces a reviewed design artifact only. It does not declare any milestone PASS and does not promote the eight-stage structure into production scope.
