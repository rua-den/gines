class_name RegionSlice
extends Node2D
## Phase 3 additive integration slice: the existing M1-M4 prototype room feeds
## into the existing M5 boss arena as one continuous loop.
##
## Only one room is instanced at a time. The prelude is removed from the tree
## before the arena is created, so there is never a duplicate player, camera or
## HUD. Progress crosses the boundary through the existing save contract
## ({evolved, nutrition}) — no existing script, scene, save field or input is
## changed. `evaluate_slice_run` is a pure rule evaluator so the progression
## rules can be pinned by a headless test without a window.

const PRELUDE_SCENE := "res://scenes/prototype.tscn"
const ARENA_SCENE := "res://scenes/boss_test.tscn"
const BOUNDARY_X := 1880.0
const COMPLETE_TEXT := "REGION COMPLETE — the path opens toward birth"

var state: String = "PRELUDE"
var prelude: Node = null
var arena: Node = null
var completion_reported: bool = false


func _ready() -> void:
	state = "PRELUDE"
	SaveState.clear(SaveState.DEFAULT_PATH)
	print("[SLICE] READY")
	_enter_prelude()


func _process(_delta: float) -> void:
	match state:
		"PRELUDE":
			_update_prelude()
		"ARENA":
			_update_arena()


func _enter_prelude() -> void:
	prelude = load(PRELUDE_SCENE).instantiate()
	add_child(prelude)


func _update_prelude() -> void:
	if prelude == null or not is_instance_valid(prelude):
		return
	var p: Node = prelude.get("player")
	if p == null:
		return
	var at_boundary: bool = p.global_position.x >= BOUNDARY_X
	if not at_boundary or not bool(p.get("evolved")):
		return
	# Hand progress to the arena through the same save M3/M5 already use.
	SaveState.write(SaveState.DEFAULT_PATH, {
		"evolved": bool(p.get("evolved")),
		"nutrition": float(p.get("nutrition")),
	})
	print("[SLICE] boundary reached; handing progress to the arena")
	_enter_arena()


func _enter_arena() -> void:
	# Detach and free the prelude BEFORE instancing the arena: one player,
	# one current camera, one HUD at any instant.
	if prelude != null and is_instance_valid(prelude):
		remove_child(prelude)
		prelude.queue_free()
	prelude = null
	arena = load(ARENA_SCENE).instantiate()
	add_child(arena)
	state = "ARENA"
	print("[SLICE] arena loaded; evolution gate open=", arena.call("gate_open"))


func _update_arena() -> void:
	if completion_reported:
		return
	if arena == null or not is_instance_valid(arena):
		return
	if not bool(arena.get("boss_defeated")):
		return
	completion_reported = true
	state = "COMPLETE"
	var label := Label.new()
	label.name = "RegionCompleteLabel"
	label.text = COMPLETE_TEXT
	label.add_theme_font_size_override("font_size", 28)
	label.position = Vector2(1300, 300)
	add_child(label)
	print("[SLICE] REGION COMPLETE")


## Pure rule evaluator: returns one named failure per broken rule (empty = PASS).
## Only keys present in `facts` are checked, so callers can assert a single rule
## in isolation. Each failure starts with its rule name followed by a colon.
func evaluate_slice_run(facts: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	# Fresh start.
	if facts.has("evolved") and bool(facts["evolved"]):
		failures.append("fresh-start: a fresh run must begin unevolved")
	if facts.has("nutrition") and facts.has("evolve_cost") \
			and float(facts["nutrition"]) >= float(facts["evolve_cost"]):
		failures.append("fresh-start: nutrition must begin below EVOLVE_COST")
	# Boundary transition (the softlock guard).
	if bool(facts.get("at_boundary", false)) and not bool(facts.get("evolved", false)):
		failures.append("transition: the boundary must not transition an unevolved player")
	# Actor uniqueness after the handoff.
	if facts.has("player_count") and int(facts["player_count"]) != 1:
		failures.append("actors: expected exactly one player, got %d" % int(facts["player_count"]))
	if facts.has("current_camera_count") and int(facts["current_camera_count"]) != 1:
		failures.append("actors: expected exactly one current camera, got %d" % int(facts["current_camera_count"]))
	# Arena handoff through the save.
	if facts.has("gate_open") and not bool(facts["gate_open"]):
		failures.append("gate: the arena must load with an open evolution gate")
	if facts.has("boss_has_player") and not bool(facts["boss_has_player"]):
		failures.append("gate: the boss must be handed the saved player")
	# Burst damage gating around the boss weak window.
	if facts.has("outside_damage") and int(facts["outside_damage"]) != 0:
		failures.append("burst-outside: burst damage outside the weak window must be zero")
	if facts.has("inside_damage") and int(facts["inside_damage"]) != 1:
		failures.append("burst-inside: burst damage inside the weak window must be exactly one")
	# Completion timing.
	if facts.has("marker_before_defeat") and bool(facts["marker_before_defeat"]):
		failures.append("completion: the marker must not appear before the boss falls")
	if facts.has("completion_count") and int(facts["completion_count"]) != 1:
		failures.append("completion: completion must be reported exactly once, got %d" % int(facts["completion_count"]))
	# Shelter retry safety.
	if facts.has("evolved") and not bool(facts["evolved"]):
		failures.append("retry: evolution must survive a shelter retry")
	if facts.has("nutrition") and float(facts["nutrition"]) < 0.0:
		failures.append("retry: nutrition must not go negative")
	if facts.has("boss_health") and facts.has("boss_max_health") \
			and int(facts["boss_health"]) != int(facts["boss_max_health"]):
		failures.append("retry: the boss must reset to full health")
	return failures
