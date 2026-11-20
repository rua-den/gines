# Review — 8-Stage Map Set

**Date:** 2026-11-21
**Scope:** design review of `map01.json` … `map08.json` against the original
repository plan. This is **not** a milestone decision. `PASS / REVISE / BLOCKED`
are reserved for milestones by `harness/project.md`; the word PASS below appears
only in the validator's observed output, which is a check result, not a verdict.
Every map remains **Proposed**; production scope is unchanged.

## Observed validator output

Command: `pwsh -NoProfile -File tools/check_maps.ps1`

```text
MAP CHECK PASSED - 8 maps, 532 checks
exit=0
```

(The runner renders the em dash in the script's output string as a hyphen.)

Negative controls — full eight-map copies with one field broken each. All
returned exit 1 with the named failure:

| Fixture | Broken field | Observed first failure |
|---|---|---|
| `missing_obstacles` | map03 `obstacles: []` | `at least 2 obstacles are required` |
| `broken_chain` | map04 `exit_unlocks: "map99"` | `exit_unlocks must be map05` |
| `dishonest_status` | map07 upgrade marked `implemented` | `implemented upgrade id is not in the build whitelist` |
| `maternal_boss` | map08 `boss.kind: "mother"` | `boss.kind must be hostile_organism (never the mother)` |
| `second_meter` | map06 `meter_count: 2` | `resources.meter_count must be 1` |
| `softlock_silence` | map05 empty `softlock_fallback` | `upgrade.softlock_fallback is required` |
| `future_gate` | map05 boss requires a stage-07 upgrade | `boss.gate_requires 'double_jump_glide' must be owned by stage 5 or earlier` |
| `hazard_no_fallback` | map04 planned hazard has no fallback | `planned obstacle needs fallback_until_implemented` |
| `linear_model` | map02 `progression.model: "connected_world"` | `progression.model must be illustrative_linear` |

The checker can fail, so its success is evidence rather than a formality.

## Per-map alignment

“Code exists” means the named upgrade/boss is present in `game/scripts/`;
it does **not** mean a milestone was accepted. M4's human check is open; M5 has
an observed automated PASS with its human feel check open
(see `docs/MILESTONES.md`). Neither has a milestone verdict.

| Map | Obstacles | Upgrade (code exists) | Boss (code exists) | Plan alignment | Progression safety | Design status |
|---|---|---|---|---|---|---|
| 01 The First Cell | 4 slabs | `surface_grip` + `crawl` (yes) | The Drifter (no; built from Predator) | `GDF §7` early movement | Two dodge routes | aligned; linear model Open |
| 02 The Divide | 4 slabs | `absorption_channel` (yes) | The Splitter (no) | `GDF §8` / `DEV §4` absorption | Motes regenerate | aligned; linear model Open |
| 03 The Golden Alcove | 4 slabs + gate | `spike_ring` + `spike_burst` (yes) | Rot Bloom (yes) | `DEV §5`; `GDF §8/§10` | Gate blocks unevolved player | aligned; M5 automated evidence recorded, human check open |
| 04 The Pulse | 4 slabs + planned hazard | `energy_pool` (yes) | The Pulse Maw (no) | `DEV §4` energy pool | Energy regenerates; M4 human check open | aligned; energy is an ability pool, not a meter |
| 05 The Calcium Vault | 5 slabs + planned hazard | `body_contraction` → dash (no) | The Vine Lash (no) | `GDF §7` contraction/dash | Dash is a shortcut, not a gate | **Open** — early-tier contraction placed mid-game |
| 06 The Budding Field | 5 slabs | run + jump + strike (no) | The Gnawer (no) | `GDF §7` later movement | Existing burst still works | **Open** — dash precedes run/jump in the listed ladder |
| 07 The Neural Bloom | 4 slabs + planned band | double-jump + glide + veil (no) | The Sentinel (no) | `GDF §7` gliding/hiding | Veil optional; two routes | **Open** — early-tier hiding placed late |
| 08 The Passage | 4 slabs + planned membrane | `integrated_form` (no) | The Last Overgrowth (no) | `DEV §6` final stage; `GDF §12` | Mother guides, never fights; any prior weapon works | aligned to ending; build variety Open |

## Cross-map checks

- **Chain:** map01 `null → map02`; map02–07 `mapNN.boss_defeated → map(N+1)`;
  map08 `map07.boss_defeated → birth`. All eight links verified by the checker.
  `progression.model` is `illustrative_linear` on every map — see the Open item below.
- **Obstacles:** ≥2 positive, in-bounds solid slabs per map; hazard zones are `planned`.
- **Upgrades:** `permanent` and `additive`, each with `softlock_fallback`;
  `capacity.equipped_limit` is `null` / `Open` on every map.
- **Bosses:** exactly one per map, all `hostile_organism`; the mother appears only
  as `guide_only` or `absent`. Gates reference only owned earlier upgrades.
- **Resources:** `single_nutrition` with `meter_count: 1`; M4 energy is modeled as
  `ability_pools: ["energy"]` on maps 03/04/08, not as a new economy meter.
- **Engine honesty:** whitelist ids only; stage 03 is the only stage whose upgrade
  and boss code both exist. No owner acceptance is implied.

## Open / Risk — recorded deviations, not silently fixed

| Item | Status | Why not fixed here |
|---|---|---|
| Linear chain vs. Confirmed interconnected world with sequence breaks and return-later signals (`GDF §11`, `DEV §6`) | **Open** | `deferred_world_fields.return_signals` is an empty stub; inventing routes would create unapproved content. Do not treat `entry_requires` as the real world graph. |
| Equipped capacity and 4–5 evolution branches (`DEV §5`, `GDF §10`) | **Open** | Additive no-branch model protects against softlocks; capacity would need a real loadout system and playtest. |
| Core loop Explore→Absorb→Evolve→Adapt→Overcome per region (`DEV §4`, `GDF §8`) | **Risk** | Only map03 has an evolution zone; abilities are granted elsewhere. Restructuring eight unapproved stages is out of scope. |
| Ability ordering: contraction/hiding early in `GDF §7` but placed at maps 05/07; dash before run/jump | **Open** | Reordering unvalidated stages would be pretend precision without playtest. |
| Per-region visual identity, secrets, narrative discoveries (`DEV §6`) | **Open** | Stub fields exist; filling them is Muse/design work requiring owner review. |
| Father details and outside-world traces (`DEV §6`, `GDF §12`) | **Open** | Narrative content deferred; `narrative.discoveries` stubs exist. |
| Eight bosses vs. "multiple bosses out of scope" (`BACKLOG.md`) | **Risk** | Design exploration only; no production commitment. |
| Planned dash/glide/combos/hazards | **Open** | Each has `fallback_until_implemented`. |

## Final verification

| Command | Observed result |
|---|---|
| `pwsh -NoProfile -File tools/check_maps.ps1` | `MAP CHECK PASSED - 8 maps, 532 checks`, exit 0 |
| 9 negative fixtures | all exit 1 with named failures |
| `pwsh -File harness/scripts/check.ps1` | `HARNESS CHECK PASSED: 65 checks`, exit 0 |
| `git status` | no `game/` changes |

These are evidence, not decisions. Only the owner can approve a direction or
record a milestone verdict.
