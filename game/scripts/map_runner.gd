class_name MapRunner
extends Node2D
## JSON-driven map runner — proof of the data -> scene path for map01 only.
##
## Reads a runtime copy of the canonical map from res://resources/maps/,
## validates it through the pure evaluate_map_run() contract, then builds the
## geometry and entities from the parsed data. No existing game script, scene,
## save field or input action is changed. Unsupported ids are rejected by name
## and never silently skipped.
##
## The planned boss (`the_drifter`) uses the existing Predator as an explicitly
## proposed placeholder; it is not an approved enemy or a second boss.

const MAP_PATH := "res://resources/maps/map01.json"
const PLAYER_SCENE := "res://scenes/player.tscn"
const EXPECTED_MAP_ID := "map01"
const SUPPORTED_BUILT_FROM := "Predator"
const SUPPORTED_OBSTACLE_KINDS := ["static_slab"]
const ENEMY_START := Vector2(1180.0, 560.0)
const ENEMY_PATROL := 200.0
const BOUNDS_MARGIN := 60.0

var map_data: Dictionary = {}
var slabs: Array[StaticBody2D] = []
var player: PlayerController = null
var enemy: Predator = null
var camera: Camera2D = null
var hud: CanvasLayer = null
var hud_label: Label = null
var room_rect: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)
var load_failures: Array[String] = []
var _min_pos := Vector2.INF
var _max_pos := Vector2(-INF, -INF)


func _ready() -> void:
	var failures := load_map_data(_load_map())
	if not failures.is_empty():
		for f in failures:
			push_error("[MAP] " + f)
		return
	print("[MAP] READY %s" % str(map_data.get("id", "")))


func _load_map() -> Dictionary:
	var file := FileAccess.open(MAP_PATH, FileAccess.READ)
	if file == null:
		push_error("[MAP] cannot open " + MAP_PATH)
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("[MAP] invalid JSON in " + MAP_PATH)
	return {}


## Translates map data into the facts the pure evaluator inspects. Missing
## built_from is represented as an empty string so it becomes a named failure
## instead of being silently absent.
func _facts_for(data: Dictionary) -> Dictionary:
	var facts: Dictionary = {}
	facts["map_id"] = str(data.get("id", ""))
	var boss: Dictionary = data.get("boss", {})
	facts["boss_built_from"] = str(boss.get("built_from", ""))
	var kinds: Array[String] = []
	var obstacles: Array = data.get("obstacles", [])
	for o in obstacles:
		if o is Dictionary:
			kinds.append(str((o as Dictionary).get("kind", "")))
	facts["obstacle_kinds"] = kinds
	return facts


## Pure rule evaluator: one named failure per broken rule, empty = safe to run.
## Only keys present in `facts` are checked, so a caller can assert one rule in
## isolation. Drift and bounds facts are supplied by callers (the drift hash is
## compared by tools/check_maps.ps1 in production; the headless test computes it).
func evaluate_map_run(facts: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if facts.has("map_id") and str(facts["map_id"]) != EXPECTED_MAP_ID:
		failures.append("unsupported: map id '%s' is not runnable (only %s is implemented)" % [
			str(facts["map_id"]), EXPECTED_MAP_ID])
	if facts.has("boss_built_from"):
		var built_from := str(facts["boss_built_from"])
		if built_from.is_empty():
			failures.append("no executable fallback: boss has no built_from entity")
		elif built_from != SUPPORTED_BUILT_FROM:
			failures.append("unsupported: boss built_from '%s' has no executable fallback" % built_from)
	if facts.has("obstacle_kinds"):
		var kinds: Array = facts["obstacle_kinds"]
		for kind in kinds:
			if not SUPPORTED_OBSTACLE_KINDS.has(str(kind)):
				failures.append("unsupported: obstacle kind '%s' has no builder" % str(kind))
	if facts.has("runtime_hash") and facts.has("canonical_hash") \
			and str(facts["runtime_hash"]) != str(facts["canonical_hash"]):
		failures.append("drift: runtime map copy differs from the canonical map")
	if facts.has("min_pos") and facts.has("max_pos") and facts.has("room_rect"):
		var min_pos: Vector2 = facts["min_pos"]
		var max_pos: Vector2 = facts["max_pos"]
		var room: Rect2 = facts["room_rect"]
		if not _within(room, min_pos) or not _within(room, max_pos):
			failures.append("bounds: the player left the room bounds")
	return failures


func _within(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y


## Gate + build in one place. On any named failure the map is rejected and no
## entity is touched, so an invalid candidate cannot half-build a scene.
func load_map_data(data: Dictionary) -> Array[String]:
	var failures := evaluate_map_run(_facts_for(data))
	if not failures.is_empty():
		load_failures = failures
		return failures
	load_failures = []
	map_data = data
	room_rect = Rect2(0.0, 0.0,
		float((data.get("room", {}) as Dictionary).get("width", 1920)),
		float((data.get("room", {}) as Dictionary).get("height", 1080)))
	_min_pos = Vector2.INF
	_max_pos = Vector2(-INF, -INF)
	_build_all(data)
	return failures


func _clear_built() -> void:
	for slab in slabs:
		if is_instance_valid(slab):
			slab.queue_free()
	slabs.clear()
	for node in [player, enemy, camera, hud]:
		if node != null and is_instance_valid(node):
			(node as Node).queue_free()
	player = null
	enemy = null
	camera = null
	hud = null
	hud_label = null


func _build_all(data: Dictionary) -> void:
	_clear_built()
	_build_slabs(data)
	_build_player(data)
	_build_enemy(data)
	_build_camera()
	_build_hud()


func _build_slabs(data: Dictionary) -> void:
	var obstacles: Array = data.get("obstacles", [])
	for i in obstacles.size():
		var obstacle: Dictionary = obstacles[i]
		if str(obstacle.get("kind", "")) != "static_slab":
			continue
		var rect_values: Array = obstacle.get("rect", [])
		if rect_values.size() != 4:
			continue
		var rect := Rect2(float(rect_values[0]), float(rect_values[1]),
			float(rect_values[2]), float(rect_values[3]))
		var slab := RoomBuilder.add_slab(self, rect, RoomBuilder.SLAB, RoomBuilder.SLAB_EDGE)
		slab.name = "Slab%d" % i
		slabs.append(slab)


func _build_player(data: Dictionary) -> void:
	var checkpoint: Dictionary = data.get("checkpoint", {})
	var pos: Array = checkpoint.get("position", [])
	var spawn := Vector2(300.0, 500.0)
	if pos.size() >= 2:
		spawn = Vector2(float(pos[0]), float(pos[1]))
	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		push_error("[MAP] cannot load " + PLAYER_SCENE)
		return
	var p: PlayerController = packed.instantiate() as PlayerController
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.position = spawn
	add_child(p)
	player = p


func _build_enemy(data: Dictionary) -> void:
	var boss: Dictionary = data.get("boss", {})
	if str(boss.get("built_from", "")) != SUPPORTED_BUILT_FROM:
		return
	var e := Predator.new()
	e.position = ENEMY_START
	e.patrol_min_x = ENEMY_START.x - ENEMY_PATROL
	e.patrol_max_x = ENEMY_START.x + ENEMY_PATROL
	e.player = player
	add_child(e)
	enemy = e


func _build_camera() -> void:
	var cam := Camera2D.new()
	cam.name = "MapCamera"
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	cam.limit_left = int(room_rect.position.x)
	cam.limit_top = int(room_rect.position.y)
	cam.limit_right = int(room_rect.end.x)
	cam.limit_bottom = int(room_rect.end.y)
	cam.position = player.global_position if player != null else room_rect.get_center()
	add_child(cam)
	cam.make_current()
	camera = cam


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.layer = 10
	add_child(layer)
	hud = layer
	var title := Label.new()
	title.name = "MapLabel"
	title.text = "GENESIS  /  %s  —  %s" % [
		str(map_data.get("id", "")).to_upper(), str(map_data.get("name", ""))]
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.56, 0.96, 0.89))
	title.offset_left = 24.0
	title.offset_top = 12.0
	title.offset_right = 920.0
	title.offset_bottom = 44.0
	layer.add_child(title)
	hud_label = title
	var hint := Label.new()
	hint.name = "MapHint"
	hint.text = "%d slabs from JSON  •  WASD swim  •  Shift grip  •  planned boss: The Drifter (Predator placeholder)" % slabs.size()
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.65, 0.8, 0.78))
	hint.offset_left = 24.0
	hint.offset_top = 42.0
	hint.offset_right = 920.0
	hint.offset_bottom = 74.0
	layer.add_child(hint)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var lo := room_rect.position + Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)
	var hi := room_rect.end - Vector2(BOUNDS_MARGIN, BOUNDS_MARGIN)
	player.global_position = player.global_position.clamp(lo, hi)
	_min_pos = _min_pos.min(player.global_position)
	_max_pos = _max_pos.max(player.global_position)
	if camera != null and is_instance_valid(camera):
		camera.global_position = player.global_position
