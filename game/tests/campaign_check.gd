extends SceneTree
## Headless regression check for the sequential Campaign mode.
##
## The campaign owns nine self-contained map stages and advances only when the
## current stage reports a boss defeat. Every case drives the real instanced
## scene by calling _process() directly (no physics-frame race), and the pure
## evaluate_campaign(facts) rule is pinned by named negative fixtures.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/campaign_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 9
const CAMPAIGN_SCENE := "res://scenes/campaign.tscn"
const MENU_SCENE := "res://scenes/main_menu.tscn"

const EXPECTED_PATHS: Array[String] = [
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

var _passed := 0
var _failed := 0
var _campaign: Node = null


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


func _guard(label: String) -> bool:
	if _campaign == null or not is_instance_valid(_campaign):
		_check(label, false, "<campaign scene missing>")
		return false
	return true


func _make_campaign() -> Node:
	var packed: PackedScene = load(CAMPAIGN_SCENE)
	if packed == null:
		return null
	var c: Node = packed.instantiate()
	# Test seams: never change the real scene tree and drive _process() only
	# from this script, so stage advancement is deterministic.
	c.set("change_scene_on_request", false)
	c.set_process(false)
	get_root().add_child(c)
	return c


func _count_class(root: Node, type_name: String) -> int:
	var count := 0
	var scr = root.get_script()
	if scr != null and scr.get_global_name() == type_name:
		count += 1
	for child in root.get_children():
		count += _count_class(child, type_name)
	return count


func _count_current_cameras(root: Node) -> int:
	var count := 0
	if root is Camera2D and (root as Camera2D).is_current():
		count += 1
	for child in root.get_children():
		count += _count_current_cameras(child)
	return count


## Pump the campaign's own _process() with a fixed delta. No frame wait needed.
func _pump(c: Node, steps: int, delta: float = 0.2) -> void:
	for i in steps:
		c.call("_process", delta)


## Mark the current stage cleared the same way a real boss defeat is observed.
func _force_clear(c: Node) -> void:
	var stage: Node = c.get("current_stage")
	if stage == null or not is_instance_valid(stage):
		return
	stage.set("boss_defeated", true)
	if stage.get("completion_reported") != null:
		stage.set("completion_reported", true)


## Force one stage to clear, then pump until the index moves or the run ends.
func _advance_one(c: Node) -> void:
	var start := int(c.get("stage_index"))
	_force_clear(c)
	for i in 20:
		if int(c.get("stage_index")) != start or bool(c.get("finished")):
			return
		_pump(c, 1)


func _has(failures: Array, rule: String) -> bool:
	for f in failures:
		if str(f).begins_with(rule):
			return true
	return false


func _evaluate(c: Node, facts: Dictionary) -> Array:
	var value: Variant = c.call("evaluate_campaign", facts)
	return value if value is Array else []


# ------------------------------------------------------------------- cases

func _case_map_paths_exact() -> void:
	if not _guard("MAP_PATHS lists map01..map09 in order"):
		return
	var paths: Array = cpaths(_campaign)
	var ok: bool = paths.size() == EXPECTED_PATHS.size()
	if ok:
		for i in EXPECTED_PATHS.size():
			if str(paths[i]) != EXPECTED_PATHS[i] or not ResourceLoader.exists(str(paths[i])):
				ok = false
				break
	_check("MAP_PATHS lists map01..map09 in order", ok,
		"count=%d paths=%s" % [paths.size(), paths])


func cpaths(c: Node) -> Array:
	var value: Variant = c.get("MAP_PATHS")
	return value if value is Array else []


func _case_initial_stage() -> void:
	if not _guard("campaign starts at map01 with one player/camera"):
		return
	var stage: Node = _campaign.get("current_stage")
	var players := _count_class(_campaign, "PlayerController")
	var cameras := _count_current_cameras(_campaign)
	var paths := cpaths(_campaign)
	var ok: bool = int(_campaign.get("stage_index")) == 0 \
		and not bool(_campaign.get("finished")) \
		and stage != null and is_instance_valid(stage) \
		and paths.size() > 0 and str(stage.get("map_id")) == "map01" \
		and players == 1 and cameras == 1
	_check("campaign starts at map01 with one player/camera", ok,
		"index=%d stage=%s players=%d cameras=%d" % [
			int(_campaign.get("stage_index")),
			stage.get("map_id") if stage != null else "<none>", players, cameras])


func _case_forcing_defeat_advances() -> void:
	if not _guard("forcing boss_defeated advances a stage"):
		return
	_advance_one(_campaign)
	var stage: Node = _campaign.get("current_stage")
	var players := _count_class(_campaign, "PlayerController")
	var cameras := _count_current_cameras(_campaign)
	var ok: bool = int(_campaign.get("stage_index")) == 1 \
		and stage != null and str(stage.get("map_id")) == "map02" \
		and players == 1 and cameras == 1 and not bool(_campaign.get("finished"))
	_check("forcing boss_defeated advances a stage", ok,
		"index=%d stage=%s players=%d cameras=%d finished=%s" % [
			int(_campaign.get("stage_index")),
			stage.get("map_id") if stage != null else "<none>",
			players, cameras, bool(_campaign.get("finished"))])


func _case_stage_complete_overlay() -> void:
	if not _guard("STAGE N COMPLETE overlay is shown"):
		return
	var c2 := _make_campaign()
	await _frames(1)
	_force_clear(c2)
	_pump(c2, 1)
	var text := str(c2.get("overlay_label").get("text")) if c2.get("overlay_label") != null else ""
	var ok: bool = text.contains("STAGE 1 COMPLETE")
	_check("STAGE N COMPLETE overlay is shown", ok, "overlay='%s'" % text)
	c2.free()


func _case_all_nine_advance() -> void:
	if not _guard("all nine stages advance to the ending"):
		return
	for i in 9:
		_advance_one(_campaign)
	var finished: bool = bool(_campaign.get("finished"))
	var players := _count_class(_campaign, "PlayerController")
	var cameras := _count_current_cameras(_campaign)
	var label: Node = _campaign.get("overlay_label")
	var text := str(label.get("text")) if label != null else ""
	var ok: bool = finished and _campaign.get("current_stage") == null \
		and players == 0 and cameras == 0 and text.contains("THE PATH OPENS TOWARD BIRTH")
	_check("all nine stages advance to the ending", ok,
		"finished=%s players=%d cameras=%d overlay='%s'" % [finished, players, cameras, text])


func _case_ending_only_after_map09() -> void:
	if not _guard("ending is unreachable before map09"):
		return
	var c3 := _make_campaign()
	await _frames(1)
	# Pump far past the overlay duration on map01 without clearing the boss.
	_pump(c3, 30)
	var premature_state: bool = bool(c3.get("finished"))
	var rule := _evaluate(c3, {
		"finished": true, "stage_index": 0, "all_stages_cleared": false,
	})
	var ok: bool = not premature_state and int(c3.get("stage_index")) == 0 \
		and _has(rule, "ending:")
	_check("ending is unreachable before map09", ok,
		"finished=%s index=%d rule=%s" % [
			premature_state, int(c3.get("stage_index")), rule])
	c3.free()


func _case_interact_returns_to_menu() -> void:
	if not _guard("interact at the ending requests Main Menu"):
		return
	# _campaign is already finished by the all-nine case.
	campaign_interact()
	var request := str(_campaign.get("last_scene_request"))
	var ok: bool = bool(_campaign.get("finished")) and request == MENU_SCENE
	_check("interact at the ending requests Main Menu", ok,
		"finished=%s request=%s" % [bool(_campaign.get("finished")), request])


func campaign_interact() -> void:
	_campaign.call("on_interact")


func _case_negative_fixtures() -> void:
	if not _guard("named negative fixtures fail evaluate_campaign"):
		return
	var bad_path := _evaluate(_campaign, {"stage_path": "res://scenes/not_a_map.tscn"})
	var bad_index := _evaluate(_campaign, {"stage_index": 99, "stage_count": 9})
	var bad_count := _evaluate(_campaign, {"stage_count": 8})
	var premature := _evaluate(_campaign, {
		"finished": true, "stage_index": 2, "all_stages_cleared": false,
	})
	var good := _evaluate(_campaign, {
		"stage_path": "res://scenes/map01.tscn",
		"stage_count": 9,
		"stage_index": 0,
		"all_stages_cleared": false,
		"finished": false,
	})
	var ok: bool = _has(bad_path, "stage:") and _has(bad_index, "stage:") \
		and _has(bad_count, "stage:") and _has(premature, "ending:") \
		and good.is_empty()
	_check("named negative fixtures fail evaluate_campaign", ok,
		"path=%s index=%s count=%s premature=%s good=%s" % [
			bad_path, bad_index, bad_count, premature, good])


func _case_pure_verdict_on_real_state() -> void:
	if not _guard("pure verdict is empty for a real cleared run"):
		return
	var facts := {
		"stage_path": str(cpaths(_campaign)[0]),
		"stage_count": cpaths(_campaign).size(),
		"stage_index": 8,
		"all_stages_cleared": true,
		"finished": true,
		"overlay_text": str(_campaign.get("overlay_label").get("text")),
		"menu_request": str(_campaign.get("last_scene_request")),
	}
	var failures := _evaluate(_campaign, facts)
	_check("pure verdict is empty for a real cleared run", failures.is_empty(),
		"facts=%s failures=%s" % [facts, failures])


# ------------------------------------------------------------------- entry

func _init() -> void:
	await _frames(2)
	_campaign = _make_campaign()
	await _frames(2)
	await _case_map_paths_exact()
	await _case_initial_stage()
	await _case_forcing_defeat_advances()
	await _case_stage_complete_overlay()
	await _case_all_nine_advance()
	await _case_ending_only_after_map09()
	await _case_interact_returns_to_menu()
	await _case_negative_fixtures()
	await _case_pure_verdict_on_real_state()
	if _campaign != null and is_instance_valid(_campaign):
		_campaign.free()
	await _frames(2)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] campaign_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
