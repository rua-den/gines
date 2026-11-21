class_name MapStage
extends Node2D
## Parameterized, JSON-driven map stage. One thin scene per map exports
## [member map_id]; this script turns that map's runtime copy into a complete
## player loop: geometry -> motes -> evolution -> gate -> boss -> completion,
## with a shelter retry that never rolls back progress.
##
## Per-map placement and copy come from @export vars (overridden in each thin
## scene); capability whitelists stay in code as honest declarations of what
## this build can execute. Unsupported ids (unknown map, a key outside the
## SCHEMA.md allow-list, an unimplemented boss with no documented fallback)
## produce NAMED failures and are never silently skipped. No existing game
## script, scene, save field or input action is changed.
##
## `--map-demo=<id>` drives the full loop headlessly and prints
## `<MAPID> RESULT: PASS` / `FAIL`, exiting 0 / 1. The legacy `--map03-demo`
## flag is still accepted.

const MAP_DIR := "res://resources/maps/"
const PLAYER_SCENE := "res://scenes/player.tscn"
## Capability whitelists: declarations of what this build can execute, not
## per-map requirements. Adding an id here is an honest feature flag.
const SUPPORTED_MAP_IDS := ["map03"]
const SUPPORTED_BOSS_IDS := ["rot_bloom"]
const SUPPORTED_BUILT_FROM := "Predator"
const SUPPORTED_OBSTACLE_KINDS := ["static_slab", "gate", "hazard_zone"]
## Implemented upgrade grants (schema v1 whitelist).
const SUPPORTED_GRANTS := ["surface_grip", "crawl", "absorption_channel",
	"spike_ring", "spike_burst", "energy_pool"]
## Allow-list of known SCHEMA.md v1 keys. A future key must be added here
## deliberately; any other key is a named `unsupported` failure, never skipped.
const KNOWN_KEYS := [
	# top level
	"artifact_type", "schema_version", "id", "stage", "name",
	"developmental_beat", "plan_refs", "room", "obstacles", "upgrade",
	"boss", "deferred_world_fields", "checkpoint", "resources", "narrative",
	"progression", "stage_status", "status",
	# room / obstacles[]
	"width", "height", "coordinate_space", "kind", "rect", "role",
	"engine_status", "fallback_until_implemented",
	# upgrade / boss
	"grants", "plan_ref", "permanent", "additive", "capacity", "note",
	"softlock_fallback", "equipped_limit", "loop", "weak_window",
	"gate_requires", "retry_rule", "built_from", "solution",
	# resources / narrative / progression
	"model", "meter_count", "ability_pools", "sources", "future_resource",
	"mother_role", "beat", "entry_requires", "exit_unlocks",
	# deferred_world_fields and its stubs
	"visual_identity", "secrets", "return_signals", "narrative_discoveries",
	"value", "entries",
	# checkpoint
	"position",
]

const MOTE_NUTRITION := 10.0
const BOUNDS_MARGIN := 60.0
const STANDOFF := 95.0
const DEMO_TIMEOUT := 90.0

const GATE_FILL := Color(0.30, 0.08, 0.24, 0.92)
const GATE_EDGE := Color(0.95, 0.45, 0.72)
const HAZARD_FILL := Color(0.28, 0.24, 0.10, 0.92)
const HAZARD_EDGE := Color(0.95, 0.78, 0.31)
const HUD_TEAL := Color(0.56, 0.96, 0.89)
const HUD_GOLD := Color(0.95, 0.76, 0.31)

@export var map_id: String = "map03"
## Per-map placement/copy. Defaults match the original map03 layout; each thin
## scene overrides them. These are presentation/config values, not capability
## whitelists (those stay in code above).
@export var mote_positions: Array[Vector2] = [Vector2(520.0, 900.0),
	Vector2(700.0, 900.0), Vector2(880.0, 900.0)]
@export var zone_pos: Vector2 = Vector2(960.0, 880.0)
@export var boss_pos: Vector2 = Vector2(1560.0, 520.0)
@export var default_checkpoint: Vector2 = Vector2(1020.0, 900.0)
@export var complete_text: String = "MAP03 COMPLETE — the golden alcove has changed you"

var map_data: Dictionary = {}
var slabs: Array[StaticBody2D] = []
var player: PlayerController = null
var motes: Array[Absorbable] = []
var zone: EvolutionZone = null
var boss: Node = null
var gate: StaticBody2D = null
var gate_end_x: float = 0.0
var camera: Camera2D = null
var hud: CanvasLayer = null
var hud_status: Label = null
var completion_marker: Label = null
var boss_defeated: bool = false
var load_failures: Array[String] = []
var room_rect: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var _checkpoint_pos := Vector2.ZERO

var _min_pos := Vector2.INF
var _max_pos := Vector2(-INF, -INF)
## Positions observed BEFORE the safety clamp — keeps the bounds rule honest.
var _raw_min := Vector2.INF
var _raw_max := Vector2(-INF, -INF)

# Demo autopilot state.
var _demo := false
var _demo_stage := 0
var _demo_stage_time := 0.0
var _demo_run_time := 0.0
var _demo_finished := false
var _bursts := 0


# -------------------------------------------------------- derived from map_id

## Log/RESULT lines and the demo flag all follow `map_id`, so a thin scene only
## has to set that one value (plus the placement exports).
func log_prefix() -> String:
	return "[%s]" % map_id.to_upper()


func demo_flag() -> String:
	return "--map-demo=%s" % map_id


func is_demo_arg(arg: String) -> bool:
	# Legacy `--map03-demo` remains accepted; the generic form is the default.
	return arg == demo_flag() or arg == "--%s-demo" % map_id


func result_line(passed: bool) -> String:
	return "%s RESULT: %s" % [map_id.to_upper(), "PASS" if passed else "FAIL"]


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if is_demo_arg(arg):
			_demo = true
	var failures := load_map_data(_load_map())
	if not failures.is_empty():
		for f in failures:
			push_error(log_prefix() + " " + f)
		if _demo:
			_demo_abort(failures)
		return
	print("%s READY %s" % [log_prefix(), str(map_data.get("id", ""))])
	if _demo:
		player.demo_active = true
		print(log_prefix(), " demo autopilot enabled")


func _load_map() -> Dictionary:
	var path := MAP_DIR + map_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error(log_prefix() + " cannot open " + path)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error(log_prefix() + " invalid JSON in " + path)
	return {}


## Resolves a boss block to one of four executable outcomes. A documented
## fallback is a non-empty `fallback_until_implemented` string. Unknown
## built_from entities are named failures, never an empty spawn.
func _boss_kind(boss_data: Dictionary) -> String:
	var boss_id := str(boss_data.get("id", ""))
	if SUPPORTED_BOSS_IDS.has(boss_id):
		return "rot_bloom"
	var fallback: Variant = boss_data.get("fallback_until_implemented", null)
	var documented: bool = fallback is String and not (fallback as String).is_empty()
	if not documented:
		return "unsupported"
	var built_from := str(boss_data.get("built_from", ""))
	if built_from.is_empty():
		# Maps 04-08 name no built_from entity: use a clearly labeled
		# BloomBoss-loop placeholder instead of silently spawning nothing.
		return "placeholder"
	if built_from == SUPPORTED_BUILT_FROM:
		return "built_from"
	return "unsupported"


## Recursively collects keys outside the SCHEMA.md allow-list at any nesting
## level, so a new future ability key cannot hide inside a nested block.
func _collect_unknown_keys(value: Variant, out: Array[String]) -> void:
	if value is Dictionary:
		var dict: Dictionary = value
		for key in dict.keys():
			var k := str(key)
			if not KNOWN_KEYS.has(k) and not out.has(k):
				out.append(k)
			_collect_unknown_keys(dict[key], out)
	elif value is Array:
		for item in (value as Array):
			_collect_unknown_keys(item, out)


## Translates map data into the facts the pure evaluator inspects. A missing
## boss id or fallback is represented explicitly so it becomes a named failure
## instead of being silently absent.
func _facts_for(data: Dictionary) -> Dictionary:
	var facts: Dictionary = {}
	facts["map_id"] = str(data.get("id", ""))
	var boss_data: Dictionary = data.get("boss", {})
	facts["boss_id"] = str(boss_data.get("id", ""))
	var boss_kind := _boss_kind(boss_data)
	facts["boss_kind"] = boss_kind
	facts["has_fallback"] = boss_kind == "built_from" or boss_kind == "placeholder"
	var kinds: Array[String] = []
	var obstacles: Array = data.get("obstacles", [])
	for o in obstacles:
		if o is Dictionary:
			kinds.append(str((o as Dictionary).get("kind", "")))
	facts["obstacle_kinds"] = kinds
	var upgrade: Dictionary = data.get("upgrade", {})
	var grants: Array[String] = []
	for g in (upgrade.get("grants", []) as Array):
		grants.append(str(g))
	facts["upgrade_grants"] = grants
	var unknown_keys: Array[String] = []
	_collect_unknown_keys(data, unknown_keys)
	facts["unknown_keys"] = unknown_keys
	return facts


## Pure rule evaluator: one named failure per broken rule, empty = safe to run.
## Only keys present in `facts` are checked, so a caller can assert one rule in
## isolation. Drift and bounds facts are supplied by callers (the drift hash is
## compared by tools/check_maps.ps1 in production; the headless test computes it).
func evaluate_map_stage(facts: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if facts.has("map_id") and not SUPPORTED_MAP_IDS.has(str(facts["map_id"])):
		failures.append("unsupported: map id '%s' is not runnable" % str(facts["map_id"]))
	# `future_ids` is kept as an accepted input for callers that assert a single
	# rule in isolation; `_facts_for` supplies `unknown_keys` from the allow-list.
	if facts.has("unknown_keys") or facts.has("future_ids"):
		var keys: Array = []
		if facts.has("unknown_keys"):
			keys = facts["unknown_keys"]
		if facts.has("future_ids"):
			keys = facts["future_ids"]
		for id in keys:
			failures.append("unsupported: unknown key '%s' is not in the SCHEMA.md allow-list" % str(id))
	if facts.has("boss_id"):
		var boss_id := str(facts["boss_id"])
		if not SUPPORTED_BOSS_IDS.has(boss_id) and not bool(facts.get("has_fallback", false)):
			failures.append("unsupported: boss id '%s' has no executable fallback" % boss_id)
	if facts.has("obstacle_kinds"):
		for kind in (facts["obstacle_kinds"] as Array):
			if not SUPPORTED_OBSTACLE_KINDS.has(str(kind)):
				failures.append("unsupported: obstacle kind '%s' has no builder" % str(kind))
	if facts.has("upgrade_grants"):
		for grant in (facts["upgrade_grants"] as Array):
			if not SUPPORTED_GRANTS.has(str(grant)):
				failures.append("unsupported: upgrade grant '%s' has no implementation" % str(grant))
	# Progression safety: the motes must be able to pay for evolution.
	if facts.has("mote_nutrition") and facts.has("evolve_cost") \
			and float(facts["mote_nutrition"]) < float(facts["evolve_cost"]):
		failures.append("progression: motes cannot pay for EVOLVE_COST")
	if facts.has("zone_before_gate") and not bool(facts["zone_before_gate"]):
		failures.append("progression: the evolution zone must sit before the gate")
	# Gate: opens only for an evolved player.
	if facts.has("evolved") and facts.has("gate_open"):
		var evolved := bool(facts["evolved"])
		var opened := bool(facts["gate_open"])
		if evolved and not opened:
			failures.append("gate: the gate must open once the player is evolved")
		if not evolved and opened:
			failures.append("gate: the gate must stay closed before evolution")
	# Boss damage only inside the exposed weak window.
	if facts.has("outside_damage") and int(facts["outside_damage"]) != 0:
		failures.append("burst-outside: burst damage outside the weak window must be zero")
	if facts.has("inside_damage") and int(facts["inside_damage"]) != 1:
		failures.append("burst-inside: burst damage inside the weak window must be exactly one")
	# Completion timing.
	if facts.has("marker_before_defeat") and bool(facts["marker_before_defeat"]):
		failures.append("completion: the marker must not appear before the boss falls")
	if facts.has("completion_count") and int(facts["completion_count"]) != 1:
		failures.append("completion: completion must be reported exactly once, got %d" \
			% int(facts["completion_count"]))
	if facts.has("boss_defeated") and not bool(facts["boss_defeated"]):
		failures.append("completion: the boss must be defeated before the map completes")
	# Shelter retry keeps progress and resets only the boss.
	if facts.has("evolved") and not bool(facts["evolved"]):
		failures.append("retry: evolution must survive a shelter retry")
	if facts.has("nutrition") and float(facts["nutrition"]) < 0.0:
		failures.append("retry: nutrition must not go negative")
	if facts.has("boss_health") and facts.has("boss_max_health") \
			and int(facts["boss_health"]) != int(facts["boss_max_health"]):
		failures.append("retry: the boss must reset to full health")
	# Bounds and runtime-copy drift.
	if facts.has("min_pos") and facts.has("max_pos") and facts.has("room_rect"):
		var min_pos: Vector2 = facts["min_pos"]
		var max_pos: Vector2 = facts["max_pos"]
		var room: Rect2 = facts["room_rect"]
		if not _within(room, min_pos) or not _within(room, max_pos):
			failures.append("bounds: the player left the room bounds")
	if facts.has("runtime_hash") and facts.has("canonical_hash") \
			and str(facts["runtime_hash"]) != str(facts["canonical_hash"]):
		failures.append("drift: runtime map copy differs from the canonical map")
	return failures


func _within(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y


## Gate + build in one place. On any named failure the map is rejected and no
## entity is touched, so an invalid candidate cannot half-build a scene.
func load_map_data(data: Dictionary) -> Array[String]:
	var failures := evaluate_map_stage(_facts_for(data))
	if not failures.is_empty():
		load_failures = failures
		return failures
	load_failures = []
	map_data = data
	var room: Dictionary = data.get("room", {})
	room_rect = Rect2(0.0, 0.0, float(room.get("width", 1920)),
		float(room.get("height", 1080)))
	_min_pos = Vector2.INF
	_max_pos = Vector2(-INF, -INF)
	_raw_min = Vector2.INF
	_raw_max = Vector2(-INF, -INF)
	_build_all(data)
	return failures


## Detach before freeing: queue_free() is deferred to end of frame, so a
## same-frame rebuild would otherwise leave two players/cameras in the tree.
func _dispose(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


func _clear_built() -> void:
	for slab in slabs:
		_dispose(slab)
	slabs.clear()
	for mote in motes:
		_dispose(mote)
	motes.clear()
	for node in [player, zone, boss, camera, hud, completion_marker]:
		_dispose(node)
	player = null
	motes = []
	zone = null
	boss = null
	gate = null
	gate_end_x = 0.0
	camera = null
	hud = null
	hud_status = null
	completion_marker = null
	boss_defeated = false
	_bursts = 0
	_demo_finished = false


func _build_all(data: Dictionary) -> void:
	_clear_built()
	_build_slabs(data)
	_build_player(data)
	_build_motes()
	_build_zone()
	_build_boss(data)
	_build_camera()
	_build_hud()


func _build_slabs(data: Dictionary) -> void:
	var obstacles: Array = data.get("obstacles", [])
	for i in obstacles.size():
		var obstacle: Dictionary = obstacles[i]
		var kind := str(obstacle.get("kind", ""))
		if not SUPPORTED_OBSTACLE_KINDS.has(kind):
			continue
		var rect_values: Array = obstacle.get("rect", [])
		if rect_values.size() != 4:
			continue
		var rect := Rect2(float(rect_values[0]), float(rect_values[1]),
			float(rect_values[2]), float(rect_values[3]))
		var color := RoomBuilder.SLAB
		var edge := RoomBuilder.SLAB_EDGE
		# `gate` and `hazard_zone` are still real slabs: they are never silently
		# skipped. Hazard damage remains an Open item; for now they are inert.
		if kind == "gate":
			color = GATE_FILL
			edge = GATE_EDGE
		elif kind == "hazard_zone":
			color = HAZARD_FILL
			edge = HAZARD_EDGE
		var slab := RoomBuilder.add_slab(self, rect, color, edge)
		slab.name = "Slab%d" % i
		slabs.append(slab)
		if kind == "gate":
			gate = slab
			gate_end_x = rect.end.x


func _build_player(data: Dictionary) -> void:
	var checkpoint: Dictionary = data.get("checkpoint", {})
	var pos: Array = checkpoint.get("position", [])
	_checkpoint_pos = default_checkpoint
	if pos.size() >= 2:
		_checkpoint_pos = Vector2(float(pos[0]), float(pos[1]))
	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		push_error(log_prefix() + " cannot load " + PLAYER_SCENE)
		return
	var p: PlayerController = packed.instantiate() as PlayerController
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.position = _checkpoint_pos
	add_child(p)
	player = p
	player.died.connect(retry)
	player.evolved_now.connect(_on_evolved_now)
	player.burst_fired.connect(_on_burst_fired)


func _build_motes() -> void:
	for pos in mote_positions:
		var mote := Absorbable.new()
		mote.process_mode = Node.PROCESS_MODE_PAUSABLE
		mote.position = pos
		mote.nutrition_value = MOTE_NUTRITION
		mote.drift = false
		add_child(mote)
		motes.append(mote)


func _build_zone() -> void:
	zone = EvolutionZone.new()
	zone.process_mode = Node.PROCESS_MODE_PAUSABLE
	zone.position = zone_pos
	add_child(zone)


func _build_boss(data: Dictionary) -> void:
	var boss_data: Dictionary = data.get("boss", {})
	var boss_id := str(boss_data.get("id", ""))
	match _boss_kind(boss_data):
		"rot_bloom":
			_spawn_bloom(boss_id, false)
		"built_from":
			# An unimplemented boss uses its built_from entity as an explicitly
			# Proposed placeholder, never as an approved enemy.
			var pred := Predator.new()
			pred.name = "BuiltFromBoss"
			pred.position = boss_pos
			pred.patrol_min_x = boss_pos.x - 120.0
			pred.patrol_max_x = boss_pos.x + 120.0
			pred.player = player
			pred.set_meta("boss_id", boss_id)
			add_child(pred)
			pred.killed.connect(_on_boss_defeated)
			boss = pred
		"placeholder", _:
			# Maps 04-08 name no built_from entity. Reuse the executable
			# BloomBoss loop as a clearly labeled, design-only placeholder;
			# the gate already rejected ids with no documented fallback.
			_spawn_bloom(boss_id, true)


func _spawn_bloom(boss_id: String, placeholder: bool) -> void:
	var bloom := BloomBoss.new()
	bloom.position = boss_pos
	bloom.name = "BossPlaceholder" if placeholder else "RotBloom"
	bloom.set_meta("boss_id", boss_id)
	if placeholder:
		bloom.set_meta("placeholder", true)
		var label := Label.new()
		label.name = "PlaceholderLabel"
		label.text = "PLACEHOLDER boss '%s' — BloomBoss loop (design-only, not approved)" % boss_id
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", HUD_GOLD)
		label.position = Vector2(0.0, -92.0)
		bloom.add_child(label)
	add_child(bloom)
	bloom.defeated.connect(_on_boss_defeated)
	boss = bloom


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "MapCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = int(room_rect.position.x)
	camera.limit_top = int(room_rect.position.y)
	camera.limit_right = int(room_rect.end.x)
	camera.limit_bottom = int(room_rect.end.y)
	camera.position = player.global_position if player != null else room_rect.get_center()
	add_child(camera)
	camera.make_current()


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.offset_left = 24.0
	label.offset_right = 920.0
	return label


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 10
	add_child(layer)
	hud = layer
	var title := _make_label("GENESIS  /  %s  —  %s" % [
		str(map_data.get("id", "")).to_upper(), str(map_data.get("name", ""))], 18, HUD_TEAL)
	title.offset_top = 12.0
	title.offset_bottom = 42.0
	layer.add_child(title)
	hud_status = _make_label("", 15, HUD_GOLD)
	hud_status.offset_top = 44.0
	hud_status.offset_bottom = 70.0
	layer.add_child(hud_status)
	var hint := _make_label(
		"WASD — swim  •  hold E near a mote — absorb  •  E at the alcove — evolve  •  J — burst",
		14, Color(0.65, 0.8, 0.78))
	hint.offset_top = 72.0
	hint.offset_bottom = 96.0
	layer.add_child(hint)


func _update_hud() -> void:
	if hud_status == null or player == null:
		return
	if not gate_open():
		hud_status.text = "Feed three motes, then evolve at the alcove (gate closed)"
	elif not boss_defeated and boss is BloomBoss:
		hud_status.text = "Bloom %d/%d  •  %s" % [
			int(boss.get("health")), BloomBoss.MAX_HEALTH, str(boss.call("phase_name"))]
	elif boss_defeated:
		hud_status.text = "The Rot Bloom has withered — the alcove is complete"
	else:
		hud_status.text = "Gate open"


# ------------------------------------------------------------------ gameplay

func gate_open() -> bool:
	return player != null and player.evolved


func _try_evolve() -> bool:
	if player == null or zone == null or player.evolved \
			or not zone.in_range(player.global_position):
		return false
	if not player.can_evolve():
		return false
	return player.evolve()


func _on_evolved_now() -> void:
	_open_gate()
	_update_hud()


func _open_gate() -> void:
	if gate == null:
		return
	gate.collision_layer = 0
	gate.collision_mask = 0
	gate.visible = false
	for child in gate.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)
	if boss is BloomBoss and player != null:
		(boss as BloomBoss).set_player(player)
	if zone != null:
		zone.mark_used()
	print(log_prefix(), " evolution gate opened")


func _on_boss_defeated() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	if completion_marker == null:
		completion_marker = _make_label(complete_text, 26, HUD_GOLD)
		completion_marker.name = "CompletionMarker"
		completion_marker.position = Vector2(1180.0, 300.0)
		completion_marker.offset_right = 1700.0
		add_child(completion_marker)
	print(log_prefix(), " REGION COMPLETE")


func _on_burst_fired(_at: Vector2) -> void:
	_bursts += 1


## Shelter retry: restore the player and the boss, never roll back progress.
func retry() -> void:
	if player == null or boss == null:
		return
	player.global_position = _checkpoint_pos
	player.revive()
	if boss.has_method("reset"):
		boss.call("reset")
	else:
		boss.set("health", Predator.MAX_HEALTH)
		boss.set("defeated", false)
	if camera != null:
		camera.global_position = _checkpoint_pos
	print(log_prefix(), " shelter retry")


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var raw := player.global_position
	_raw_min = _raw_min.min(raw)
	_raw_max = _raw_max.max(raw)
	var lo := room_rect.position + Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)
	var hi := room_rect.end - Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)
	player.global_position = raw.clamp(lo, hi)
	_min_pos = _min_pos.min(player.global_position)
	_max_pos = _max_pos.max(player.global_position)
	if camera != null and is_instance_valid(camera):
		camera.global_position = player.global_position
	_update_hud()
	if _demo and not _demo_finished:
		_demo_update(delta)


# --------------------------------------------------------------------- demo

func _advance_demo(stage: int) -> void:
	_demo_stage = stage
	_demo_stage_time = 0.0


func _nearest_mote() -> Absorbable:
	var best: Absorbable = null
	var best_dist := 1e9
	for mote in motes:
		if mote.consumed:
			continue
		var d := player.global_position.distance_to(mote.global_position)
		if d < best_dist:
			best = mote
			best_dist = d
	return best


func _demo_update(delta: float) -> void:
	_demo_stage_time += delta
	_demo_run_time += delta
	if _demo_run_time > DEMO_TIMEOUT:
		_demo_abort(["timeout: the demo exceeded %.0f s at stage %d" % [
			DEMO_TIMEOUT, _demo_stage]])
		return
	match _demo_stage:
		0:
			_demo_feed()
		1:
			_demo_evolve()
		2:
			_demo_gate()
		3:
			_demo_combat()
		4:
			if _demo_stage_time > 0.3:
				_finish_demo([])


func _demo_feed() -> void:
	var mote := _nearest_mote()
	if player.nutrition >= player.EVOLVE_COST or mote == null:
		player.demo_dir = Vector2.ZERO
		player.demo_interact_held = false
		_advance_demo(1)
		return
	var to_mote := mote.global_position - player.global_position
	player.demo_dir = to_mote.normalized() if to_mote.length() > 40.0 else Vector2.ZERO
	player.demo_interact_held = to_mote.length() <= PlayerController.ABSORB_RANGE - 5.0


func _demo_evolve() -> void:
	var to_zone := zone.global_position - player.global_position
	player.demo_dir = to_zone.normalized() if to_zone.length() > 20.0 else Vector2.ZERO
	player.demo_interact_held = false
	if zone.in_range(player.global_position) and player.can_evolve() and _try_evolve():
		_advance_demo(2)


func _demo_gate() -> void:
	player.demo_interact_held = false
	player.demo_attack_pressed = false
	if not gate_open():
		return
	if player.global_position.x > gate_end_x + 90.0:
		_advance_demo(3)
		return
	player.demo_dir = Vector2.RIGHT


func _demo_combat() -> void:
	player.demo_interact_held = false
	if boss_defeated or (boss != null and bool(boss.get("is_defeated"))):
		player.demo_dir = Vector2.ZERO
		player.demo_attack_pressed = false
		if _demo_stage_time > 0.3:
			_advance_demo(4)
		return
	var to_boss := (boss as Node2D).global_position - player.global_position
	var d := to_boss.length()
	if boss is BloomBoss and (boss as BloomBoss).phase == "exposed":
		player.demo_attack_pressed = d <= PlayerController.BURST_RANGE - 8.0 \
			and player.can_attack()
	else:
		player.demo_attack_pressed = false
	if d > STANDOFF + 10.0:
		player.demo_dir = to_boss.normalized()
	elif d < STANDOFF - 10.0:
		player.demo_dir = -to_boss.normalized()
	else:
		player.demo_dir = Vector2.ZERO


func _demo_facts() -> Dictionary:
	return {
		"map_id": str(map_data.get("id", "")),
		"evolved": player != null and player.evolved,
		"gate_open": gate_open(),
		"completion_count": 1 if completion_marker != null else 0,
		"boss_defeated": boss_defeated,
		"nutrition": float(player.nutrition) if player != null else -1.0,
		"min_pos": _min_pos,
		"max_pos": _max_pos,
		"room_rect": room_rect,
	}


func _demo_abort(extra: Array[String]) -> void:
	_demo_finished = true
	var failures: Array[String] = []
	for f in extra:
		failures.append(f)
	for f in failures:
		print(log_prefix(), " FAILED: ", f)
	print(result_line(false))
	get_tree().quit(1)


func _finish_demo(extra: Array[String]) -> void:
	_demo_finished = true
	if player != null:
		player.demo_dir = Vector2.ZERO
		player.demo_interact_held = false
		player.demo_attack_pressed = false
	var failures := evaluate_map_stage(_demo_facts())
	if _bursts < 3:
		failures.append("burst-inside: only %d bursts fired (need at least 3)" % _bursts)
	for f in extra:
		failures.append(f)
	for f in failures:
		print(log_prefix(), " FAILED: ", f)
	print(log_prefix(), " demo: evolved=", player != null and player.evolved,
		" defeated=", boss_defeated, " bursts=", _bursts,
		" nutrition=", float(player.nutrition) if player != null else -1.0)
	print(result_line(failures.is_empty()))
	get_tree().quit(0 if failures.is_empty() else 1)
