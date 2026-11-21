class_name Campaign
extends Node2D
## Sequential Campaign mode: instances one self-contained map stage at a time
## (map01 -> map09), advances when that stage reports a boss defeat, and shows
## an honest signpost toward birth at the end. No autoload, no cross-map save
## format and no birth cinematic are introduced.
##
## Stage completion is polled in _process() (not _physics_process()) so a
## headless check can drive advancement deterministically by calling _process()
## directly. `--campaign-demo` autopilots the whole run and prints
## `CAMPAIGN RESULT: PASS` / `FAIL`.

const MENU_PATH := "res://scenes/main_menu.tscn"
const MAP_PATHS: Array[String] = [
	"res://scenes/map01.tscn",
	"res://scenes/map02.tscn",
	"res://scenes/map03.tscn",
	"res://scenes/map04.tscn",
	"res://scenes/map05.tscn",
	"res://scenes/map06.tscn",
	"res://scenes/map07.tscn",
	"res://scenes/map08.tscn",
	"res://scenes/map09.tscn",
]
const OVERLAY_SECONDS := 0.6
const OVERLAY_BG := Color(0.025, 0.075, 0.09, 0.88)
const OVERLAY_EDGE := Color(0.95, 0.76, 0.31)
const OVERLAY_TEXT := Color(0.98, 0.96, 0.93)

var stage_index: int = 0
var finished: bool = false
var current_stage: Node = null
var overlay: CanvasLayer = null
var overlay_label: Label = null
## Test seams: real gameplay changes scenes; a headless check observes requests.
var change_scene_on_request: bool = true
var last_scene_request: String = ""

var _stage_announced: bool = false
var _overlay_elapsed: float = 0.0
var _cleared_count: int = 0
var _campaign_demo: bool = false
var _demo_finished: bool = false


func _ready() -> void:
	_build_overlay()
	_load_stage(0)
	print("[CAMPAIGN] READY")
	for arg in OS.get_cmdline_user_args():
		if arg == "--campaign-demo":
			_campaign_demo = true
	if _campaign_demo:
		# The autopilot drives _process() itself; disable the automatic tick.
		set_process(false)
		call_deferred("_campaign_demo_run")


func _unhandled_input(event: InputEvent) -> void:
	if finished and event.is_action_pressed("interact"):
		on_interact()


# ------------------------------------------------------------------- overlay

func _build_overlay() -> void:
	var root := Node.new()
	root.name = "Overlay"
	add_child(root)
	var layer := CanvasLayer.new()
	layer.name = "OverlayLayer"
	layer.layer = 20
	root.add_child(layer)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 120)
	panel.position = Vector2(160, 210)
	panel.size = Vector2(640, 120)
	var style := StyleBoxFlat.new()
	style.bg_color = OVERLAY_BG
	style.border_color = OVERLAY_EDGE
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var label := Label.new()
	label.name = "OverlayLabel"
	label.text = ""
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", OVERLAY_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)
	overlay = layer
	overlay_label = label
	layer.visible = false


func _show_overlay(text: String) -> void:
	if overlay_label != null:
		overlay_label.text = text
	if overlay != null:
		overlay.visible = true


func _hide_overlay() -> void:
	if overlay != null:
		overlay.visible = false


# ---------------------------------------------------------------- stage flow

func _dispose(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.queue_free()


func _load_stage(index: int) -> void:
	if current_stage != null:
		_dispose(current_stage)
	current_stage = null
	if index < 0 or index >= MAP_PATHS.size():
		return
	stage_index = index
	_stage_announced = false
	_overlay_elapsed = 0.0
	_hide_overlay()
	var packed: PackedScene = load(MAP_PATHS[index])
	if packed == null:
		push_error("[CAMPAIGN] cannot load stage " + MAP_PATHS[index])
		return
	current_stage = packed.instantiate()
	add_child(current_stage)


func _show_ending() -> void:
	if current_stage != null:
		_dispose(current_stage)
	current_stage = null
	finished = true
	# Signpost only: the birth cinematic remains an Open design item.
	_show_overlay("THE PATH OPENS TOWARD BIRTH")


func _stage_defeated(stage: Node) -> bool:
	var flag: Variant = stage.get("boss_defeated")
	var defeated: bool = flag != null and bool(flag)
	var reported: Variant = stage.get("completion_reported")
	if reported != null and bool(reported):
		defeated = true
	return defeated


func _process(delta: float) -> void:
	if finished:
		return
	if current_stage == null or not is_instance_valid(current_stage):
		return
	if not _stage_announced:
		if _stage_defeated(current_stage):
			_stage_announced = true
			_overlay_elapsed = 0.0
			_cleared_count += 1
			_show_overlay("STAGE %d COMPLETE" % (stage_index + 1))
		return
	_overlay_elapsed += delta
	if _overlay_elapsed >= OVERLAY_SECONDS:
		if stage_index + 1 >= MAP_PATHS.size():
			_show_ending()
		else:
			_load_stage(stage_index + 1)


func on_interact() -> void:
	if not finished:
		return
	_request_scene(MENU_PATH)


func _request_scene(path: String) -> void:
	last_scene_request = path
	if change_scene_on_request and get_tree() != null:
		get_tree().change_scene_to_file(path)


# --------------------------------------------------------------- pure verdict

## Pure rule evaluator: one named failure per broken rule, empty = PASS.
## Only keys present in `facts` are checked so each rule can be isolated.
func evaluate_campaign(facts: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	var count := MAP_PATHS.size()
	if facts.has("stage_count") and int(facts["stage_count"]) != count:
		failures.append("stage: expected %d maps, got %d" % [count, int(facts["stage_count"])])
	if facts.has("stage_index"):
		var idx := int(facts["stage_index"])
		if idx < 0 or idx >= count:
			failures.append("stage: index %d out of range for %d maps" % [idx, count])
	if facts.has("stage_path") and not MAP_PATHS.has(str(facts["stage_path"])):
		failures.append("stage: unknown stage path '%s'" % str(facts["stage_path"]))
	if facts.has("completion_count") and int(facts["completion_count"]) != count:
		failures.append("stage: expected %d completions, got %d" % [
			count, int(facts["completion_count"])])
	if facts.has("players") and int(facts["players"]) != 1:
		failures.append("actors: expected exactly one player, got %d" % int(facts["players"]))
	if facts.has("cameras") and int(facts["cameras"]) != 1:
		failures.append("actors: expected exactly one current camera, got %d" % int(facts["cameras"]))
	if facts.has("finished") and bool(facts["finished"]):
		if facts.has("stage_index") and int(facts["stage_index"]) != count - 1:
			failures.append("ending: campaign cannot finish before map%02d" % count)
		if facts.has("all_stages_cleared") and not bool(facts["all_stages_cleared"]):
			failures.append("ending: all nine stages must be cleared before the ending")
		if facts.has("overlay_text") and not str(facts["overlay_text"]).contains("BIRTH"):
			failures.append("ending: the signpost must point toward birth")
		if facts.has("menu_request") and str(facts["menu_request"]) != MENU_PATH \
				and not str(facts["menu_request"]).is_empty():
			failures.append("ending: interact must return to Main Menu")
	return failures


# ------------------------------------------------------------------ autopilot

func _demo_facts() -> Dictionary:
	return {
		"stage_count": MAP_PATHS.size(),
		"stage_index": stage_index,
		"completion_count": _cleared_count,
		"all_stages_cleared": _cleared_count == MAP_PATHS.size(),
		"finished": finished,
		"overlay_text": overlay_label.text if overlay_label != null else "",
	}


func _campaign_demo_run() -> void:
	if _demo_finished:
		return
	var guard := 0
	while not finished and guard < 400 and not _demo_finished:
		if current_stage != null and not _stage_announced:
			current_stage.set("boss_defeated", true)
			if current_stage.get("completion_reported") != null:
				current_stage.set("completion_reported", true)
		_process(0.2)
		guard += 1
	_demo_finished = true
	if not finished:
		print("[CAMPAIGN] FAILED: run did not reach the ending (cleared=%d/%d)" % [
			_cleared_count, MAP_PATHS.size()])
		print("CAMPAIGN RESULT: FAIL")
		get_tree().quit(1)
		return
	var failures := evaluate_campaign(_demo_facts())
	for f in failures:
		print("[CAMPAIGN] FAILED: ", f)
	print("CAMPAIGN RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
