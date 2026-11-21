# map<NN>.json — field contract

**Status:** Proposed design artifact. These files are **not** loaded by Godot.
**Coordinate space:** design-only, 1920×1080 world units, matching the scale of
the existing M1/M2 rooms. Rectangles are illustrative layouts, not extracted
constants from `game/scripts/room_builder.gd`.

`engine_status` and `stage_status` mean **the corresponding code exists in the
build**. They never mean owner acceptance, and they are **not** milestone
verdicts (PASS / REVISE / BLOCKED are reserved by `harness/project.md`).

Every map01.json … map09.json has these fields:

| Field | Type | Rule |
|---|---|---|
| `artifact_type` | string | `"design_only"` |
| `schema_version` | int | `1` |
| `id` | string | `"mapNN"`, matching the file name |
| `stage` | int | 1–9, matching the file name |
| `name` | string | working name, not approved art direction |
| `developmental_beat` | string | the life stage this map expresses |
| `plan_refs` | string[] | source links; ability ladder → `GAME_DESIGN_FOUNDATION.md §7`, core loop → §8 / `DEVELOPMENT_PLAN.md §4`, evolution → §10 / DEV PLAN §5 |
| `room` | object | `width: 1920`, `height: 1080`, `coordinate_space: "design_only"` |
| `obstacles` | object[] | ≥2 entries with `kind: "static_slab"`; see below |
| `upgrade` | object | exactly one; see below |
| `boss` | object | exactly one; see below |
| `deferred_world_fields` | object | stubs for §6 region requirements; all `status: "Open"`, no invented content |
| `checkpoint` | object | `kind: "shelter"`; biological shelter save/heal point |
| `resources` | object | `model: "single_nutrition"`, `meter_count: 1`; see below |
| `narrative` | object | `mother_role` ∈ `{guide_only, absent}` |
| `progression` | object | `model: "illustrative_linear"`, `entry_requires`, `exit_unlocks` |
| `stage_status` | string | derived from features, never asserted by hand |
| `status` | string | `"Proposed"` |

`obstacles[]` entries: `id`, `kind` ∈ `{static_slab, gate, hazard_zone}`,
`rect` = `[x, y, width, height]` with positive width/height inside the room,
`role` (player-facing purpose) and `engine_status`. A `planned` obstacle must
also name `fallback_until_implemented`. `hazard_zone` may never be
`implemented`; it is a planned telegraphed damage area. `static_slab` and `gate`
are implemented primitives (the gate follows the M5 evolution gate).

`upgrade`: `id`, `grants[]`, `name`, `plan_ref`, `permanent: true`,
`additive: true`, `capacity` (`equipped_limit: null`, `status: "Open"`),
`engine_status`, `softlock_fallback`, and `fallback_until_implemented` (null when
implemented, a non-empty string when planned). Upgrades are owned forever;
there are no mutually exclusive branches in this design set. The equipped
capacity and 4–5 evolution branches of `DEVELOPMENT_PLAN.md §5` are **Open**,
not represented here.

`boss`: `id`, `name`, `kind: "hostile_organism"`, `engine_status`, `loop`,
`weak_window`, `gate_requires[]` (upgrade ids from this or an earlier stage),
`retry_rule: "shelter"`, `softlock_fallback`, `fallback_until_implemented`,
and optionally `built_from` / `solution`. The mother is never a boss.

`resources.meter_count` counts **progression currencies**, not ability pools.
`single_nutrition` is the only progression currency implemented. M4 energy is
an ability-cost pool (`docs/MILESTONES.md` Milestone 4) and appears as
`ability_pools: ["energy"]` on the maps that rely on it. Creating a second
economy meter remains **Open** under `DEVELOPMENT_PLAN.md §4`.
`future_resource` is either `null` or an object with `name` and `status: "Open"`.
`note` is an optional free-form design annotation on `upgrade`, `boss` or
`future_resource`. It is non-executable and ignored by runtime; it is never a
resource or progress field. The runtime allow-list accepts it by name.

`deferred_world_fields` holds `visual_identity`, `secrets`, `return_signals`
and `narrative_discoveries` as empty stubs with `status: "Open"`.
`DEVELOPMENT_PLAN.md §6` requires each region to provide these; the fields
exist so the requirement is visible, but no deferred content is invented.

`progression.model` is always `"illustrative_linear"`. The linear
`entry_requires = previous.boss_defeated` chain is a **design simplification**,
not the Confirmed world graph. `GAME_DESIGN_FOUNDATION.md §11` and
`DEVELOPMENT_PLAN.md §6` require one interconnected world with abilities that
open routes, sequence breaks and return-later signals. Do **not** feed
`entry_requires` to a loader as the real progression graph. The illustrative
chain runs 1..9: `map01.entry_requires` is null, maps 02–09 require the previous
map's `boss_defeated`, maps 01–08 unlock the next map, and `map09.exit_unlocks`
is the terminal `"birth"`. Birth itself stays an Open cinematic.

`stage_status` is **derived from features**, not asserted:
- upgrade and boss both `implemented` → `implemented`
- exactly one `implemented` → `partial`
- neither → `planned`

Implemented ids today (the checker's whitelist; code exists, not owner-accepted):
- upgrades: `surface_grip`, `crawl`, `absorption_channel`, `spike_ring`,
  `spike_burst`, `energy_pool`
- bosses: `rot_bloom`, `the_convergence`
- obstacle kinds: `static_slab`, `gate`

Everything else is `planned` and must state `fallback_until_implemented`.
Grants have two tiers: `SUPPORTED_GRANTS` = executable code exists; `PLANNED_GRANTS` = known unimplemented ids accepted at runtime only when the scene acknowledges them and the JSON states `planned` with a non-empty `fallback_until_implemented` (Proposed placeholders, not capability claims). Run `pwsh -File tools/check_maps.ps1` to enforce this contract.
