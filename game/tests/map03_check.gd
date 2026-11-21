extends SceneTree
## Headless rule check for the parameterized map03 stage.
##
## Fifteen named cases. Each case pairs the stage's pure evaluate_map_stage()
## contract with a real assertion on the instanced scene or on the map files, so
## a stage that only implements the evaluator but never builds the scene cannot
## pass. Violating facts are fed to the evaluator (deleting a named rule fails)
## and real scene state is driven (broken integration fails). The unsupported-id
## case is a negative fixture: a rejected candidate must leave the scene intact.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/map03_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 17
const MAP_RES := "res://resources/maps/map03.json"
const STAGE_SCENE := "res://scenes/map03.tscn"
const EXPECTED_ID := "map03"
const EXPECTED_OBSTACLES := 5
const EXPECTED_MOTES := 3
const GATE_X := 1080.0
const EPS := 0.001

var _passed := 0
var _failed := 0
var _stage: Node = null
var _json: Dictionary = {}


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


# ------------------------------------------------------------------ helpers

func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _canonical_path() -> String:
	# Test-only: the canonical map lives outside res://. The stage never uses
	# this path (runtime copies are read from res://resources/maps/).
	return ProjectSettings.globalize_path("res://") + "../docs/maps/map03.json"


func _sha256_bytes(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		return ""
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()


func _sha256_file(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	return _sha256_bytes(bytes)


func _make_stage() -> Node:
	var packed: PackedScene = load(STAGE_SCENE)
	if packed == null:
		return null
	var s: Node = packed.instantiate()
	get_root().add_child(s)
	return s


func _failures(facts: Dictionary) -> Array:
	if _stage == null or not _stage.has_method("evaluate_map_stage"):
		return []
	var value: Variant = _stage.call("evaluate_map_stage", facts)
	return value if value is Array else []


func _has(failures: Array, rule: String) -> bool:
	for f in failures:
		if str(f).begins_with(rule):
			return true
	return false


func _obstacle_rects(data: Dictionary) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var obstacles: Array = data.get("obstacles", [])
	for o in obstacles:
		if not (o is Dictionary):
			continue
		var r: Array = o.get("rect", [])
		if r.size() != 4:
			continue
		rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	return rects


func _body_rect(body: StaticBody2D) -> Rect2:
	for child in body.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null:
			continue
		var box := shape_node.shape as RectangleShape2D
		if box == null:
			continue
		return Rect2(shape_node.position - box.size / 2.0, box.size)
	return Rect2()


func _rect_eq(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) <= EPS and a.size.distance_to(b.size) <= EPS


func _room_rect(data: Dictionary) -> Rect2:
	var room: Dictionary = data.get("room", {})
	return Rect2(0.0, 0.0, float(room.get("width", 1920)), float(room.get("height", 1080)))


func _within(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y


## Put the stage player in burst range of the boss with a ready body.
func _prepare_burst(p: Node, boss: Node) -> void:
	p.set("evolved", true)
	p.set("dead", false)
	p.set("energy", float(p.get("MAX_ENERGY")))
	p.set("_burst_cooldown", 0.0)
	(p as Node2D).global_position = (boss as Node2D).global_position + Vector2(-90.0, 0.0)


# ------------------------------------------------------------------- cases

func _case_runtime_json_loads() -> void:
	var parsed := _read_json(MAP_RES)
	var id_ok: bool = str(parsed.get("id", "")) == EXPECTED_ID
	var obstacles: Variant = parsed.get("obstacles", [])
	var count_ok: bool = obstacles is Array and (obstacles as Array).size() == EXPECTED_OBSTACLES
	var rdata: Dictionary = {}
	if _stage != null:
		var value: Variant = _stage.get("map_data")
		if value is Dictionary:
			rdata = value
	var runner_ok: bool = _stage != null \
		and str(rdata.get("id", "")) == EXPECTED_ID \
		and (rdata.get("obstacles", []) as Array).size() == EXPECTED_OBSTACLES
	var failures: Variant = _stage.get("load_failures") if _stage != null else null
	var gate_ok: bool = failures is Array and (failures as Array).is_empty()
	var ok: bool = id_ok and count_ok and runner_ok and gate_ok
	_check("runtime JSON loads and matches canonical id", ok,
		"id=%s obstacles=%s runner_id=%s gate=%s" % [
			parsed.get("id", "<none>"),
			(obstacles as Array).size() if obstacles is Array else "?",
			rdata.get("id", "<none>"), failures])


func _case_slabs_match_rects() -> void:
	var expected := _obstacle_rects(_json)
	var slabs: Variant = _stage.get("slabs") if _stage != null else null
	var ok: bool = slabs is Array and (slabs as Array).size() == expected.size()
	if ok:
		for i in expected.size():
			var body := (slabs as Array)[i] as StaticBody2D
			if body == null or int(body.collision_layer) != 2 \
					or not _rect_eq(_body_rect(body), expected[i]):
				ok = false
				break
	_check("slabs match every JSON rect (gate included)", ok,
		"expected=%d actual=%s" % [expected.size(),
			(slabs as Array).size() if slabs is Array else "<no stage>"])


func _case_player_at_checkpoint() -> void:
	var cp: Dictionary = _json.get("checkpoint", {})
	var pos: Array = cp.get("position", [])
	var expect := Vector2(float(pos[0]), float(pos[1])) if pos.size() >= 2 else Vector2(-1, -1)
	var p: Node = _stage.get("player") if _stage != null else null
	var ok: bool = expect == Vector2(1020.0, 900.0) \
		and p != null and p is PlayerController \
		and is_equal_approx((p as Node2D).position.x, expect.x) \
		and is_equal_approx((p as Node2D).position.y, expect.y) \
		and not bool(p.get("evolved")) \
		and is_zero_approx(float(p.get("nutrition")))
	_check("player spawns at the JSON checkpoint", ok,
		"expect=%s actual=%s evolved=%s nutrition=%s" % [expect,
			(p as Node2D).position if p != null else "<none>",
			p.get("evolved") if p != null else "?",
			p.get("nutrition") if p != null else "?"])


func _case_motes_and_zone() -> void:
	var motes: Variant = _stage.get("motes") if _stage != null else null
	var zone: Node = _stage.get("zone") if _stage != null else null
	var count := 0
	var total := 0.0
	if motes is Array:
		for m in (motes as Array):
			if m is Absorbable:
				count += 1
				total += float(m.get("nutrition_value"))
	var rule_ok := _failures({
		"mote_nutrition": total,
		"evolve_cost": PlayerController.EVOLVE_COST,
		"zone_before_gate": zone != null and (zone as Node2D).global_position.x < GATE_X,
	})
	var ok: bool = count == EXPECTED_MOTES \
		and is_equal_approx(total, PlayerController.EVOLVE_COST) \
		and zone is EvolutionZone \
		and (zone as Node2D).global_position.x < GATE_X \
		and not _has(rule_ok, "progression")
	var bad := _failures({
		"mote_nutrition": PlayerController.EVOLVE_COST - 10.0,
		"evolve_cost": PlayerController.EVOLVE_COST,
		"zone_before_gate": true,
	})
	ok = ok and _has(bad, "progression")
	_check("three motes pay for evolution; zone is before the gate", ok,
		"motes=%d nutrition=%.0f cost=%.0f zone=%s rules=%s" % [
			count, total, PlayerController.EVOLVE_COST,
			zone.global_position if zone != null else "<none>", rule_ok])


func _case_gate_closed_then_open() -> void:
	var gate := _stage.get("gate") as StaticBody2D if _stage != null else null
	var p: Node = _stage.get("player") if _stage != null else null
	var closed_before: bool = gate != null and int(gate.collision_layer) == 2 \
		and not bool(_stage.call("gate_open"))
	var evolved := false
	if p != null:
		p.set("nutrition", float(p.get("EVOLVE_COST")))
		evolved = bool(p.call("evolve"))
	await _frames(1)
	var open_after: bool = gate != null and int(gate.collision_layer) == 0 \
		and bool(_stage.call("gate_open")) and not gate.visible
	var bad := _failures({"evolved": true, "gate_open": false})
	var good := _failures({"evolved": true, "gate_open": true})
	var early := _failures({"evolved": false, "gate_open": true})
	var ok: bool = closed_before and evolved and open_after \
		and _has(bad, "gate") and not _has(good, "gate") and _has(early, "gate")
	_check("gate stays closed until evolution, then opens", ok,
		"closed_before=%s evolved=%s open_after=%s bad=%s early=%s" % [
			closed_before, evolved, open_after, bad, early])


func _case_boss_is_bloom() -> void:
	var boss: Node = _stage.get("boss") if _stage != null else null
	var boss_id := str((_json.get("boss", {}) as Dictionary).get("id", ""))
	var rule := _failures({"boss_id": boss_id})
	var ok: bool = boss_id == "rot_bloom" and boss is BloomBoss \
		and int(boss.get("health")) == BloomBoss.MAX_HEALTH \
		and not _has(rule, "unsupported")
	_check("boss id rot_bloom resolves to BloomBoss", ok,
		"boss_id=%s boss=%s health=%s" % [boss_id,
			boss.get_script().get_global_name() if boss != null and boss.get_script() != null else "<none>",
			boss.get("health") if boss != null else "?"])


func _case_boss_hud_shows_real_max_health() -> void:
	var p: Node = _stage.get("player") if _stage != null else null
	var boss: Node = _stage.get("boss") if _stage != null else null
	var hud: Node = _stage.get("hud_status") if _stage != null else null
	var text := ""
	if p != null and boss != null and hud != null:
		p.set("evolved", true)
		boss.call("reset")
		_stage.call("_update_hud")
		text = str(hud.get("text"))
	var expected := "Bloom %d/%d" % [int(boss.get("health")), int(boss.call("max_health"))] \
		if boss != null and boss.has_method("max_health") else ""
	var ok: bool = expected != "" and text.contains(expected) and text.contains("/6")
	_check("Boss HUD uses the boss's real max health", ok,
		"hud='%s' expected='%s'" % [text, expected])


func _case_burst_window() -> void:
	var outside_rule := _failures({"outside_damage": 1})
	var inside_rule := _failures({"inside_damage": 0})
	var boss := _stage.get("boss") as BloomBoss if _stage != null else null
	var p: Node = _stage.get("player") if _stage != null else null
	var outside_dealt := -1
	var inside_dealt := -1
	var outside_fired := false
	var inside_fired := false
	if boss != null and p != null:
		boss.reset()
		_prepare_burst(p, boss)
		boss.phase = "telegraph"
		var before := int(boss.health)
		outside_fired = bool(p.call("spike_burst"))
		outside_dealt = before - int(boss.health)
		p.set("energy", float(p.get("MAX_ENERGY")))
		p.set("_burst_cooldown", 0.0)
		boss.phase = "exposed"
		before = int(boss.health)
		inside_fired = bool(p.call("spike_burst"))
		inside_dealt = before - int(boss.health)
	var ok: bool = _has(outside_rule, "burst-outside") and _has(inside_rule, "burst-inside") \
		and outside_fired and inside_fired and outside_dealt == 0 and inside_dealt == 1
	_check("burst deals 0 outside / exactly 1 inside the weak window", ok,
		"outside_fired=%s outside_dealt=%d inside_fired=%s inside_dealt=%d rules=%s/%s" % [
			outside_fired, outside_dealt, inside_fired, inside_dealt, outside_rule, inside_rule])


func _case_completion_marker() -> void:
	var marker_before: bool = _stage.has_node("CompletionMarker") if _stage != null else true
	var boss := _stage.get("boss") as BloomBoss if _stage != null else null
	if boss != null:
		boss.phase = "exposed"
		boss.call("take_damage", BloomBoss.MAX_HEALTH)
	await _frames(2)
	var defeated: bool = bool(_stage.get("boss_defeated")) if _stage != null else false
	var markers := 0
	if _stage != null:
		for child in _stage.get_children():
			if child.name == "CompletionMarker" and child is Label:
				markers += 1
	var good := _failures({
		"marker_before_defeat": false,
		"completion_count": markers,
		"boss_defeated": defeated,
	})
	var bad_early := _failures({"marker_before_defeat": true})
	var bad_count := _failures({"completion_count": 0})
	var bad_boss := _failures({"boss_defeated": false})
	var ok: bool = not marker_before and defeated and markers == 1 \
		and not _has(good, "completion") and _has(bad_early, "completion") \
		and _has(bad_count, "completion") and _has(bad_boss, "completion")
	_check("completion marker waits for the boss to fall", ok,
		"before=%s defeated=%s markers=%d failures=%s" % [
			marker_before, defeated, markers, good])


func _case_retry_preserves_progress() -> void:
	var boss: Node = _stage.get("boss") if _stage != null else null
	var p: Node = _stage.get("player") if _stage != null else null
	var evolved_before: bool = bool(p.get("evolved")) if p != null else false
	var nutrition_before: float = float(p.get("nutrition")) if p != null else -1.0
	if _stage != null:
		_stage.call("retry")
	await _frames(1)
	var facts := {
		"evolved": bool(p.get("evolved")) if p != null else false,
		"nutrition": float(p.get("nutrition")) if p != null else -1.0,
		"boss_health": int(boss.get("health")) if boss != null else -1,
		"boss_max_health": BloomBoss.MAX_HEALTH,
	}
	var good := _failures(facts)
	var bad := _failures({
		"evolved": false, "nutrition": -1.0,
		"boss_health": 1, "boss_max_health": BloomBoss.MAX_HEALTH,
	})
	var at_shelter: bool = p != null \
		and is_equal_approx((p as Node2D).global_position.x, 1020.0) \
		and is_equal_approx((p as Node2D).global_position.y, 900.0)
	var ok: bool = evolved_before and bool(facts["evolved"]) \
		and is_equal_approx(float(facts["nutrition"]), nutrition_before) \
		and int(facts["boss_health"]) == BloomBoss.MAX_HEALTH \
		and at_shelter and not _has(good, "retry") and _has(bad, "retry")
	_check("shelter retry keeps progress and resets the boss", ok,
		"evolved=%s nutrition=%.0f boss_hp=%d at_shelter=%s failures=%s" % [
			facts["evolved"], float(facts["nutrition"]), int(facts["boss_health"]),
			at_shelter, good])


func _case_player_traverses_in_bounds() -> void:
	if _stage == null:
		_check("player traverses toward the gate inside bounds", false, "<no stage>")
		return
	var p: Node = _stage.get("player")
	if p == null or not (p is Node2D):
		_check("player traverses toward the gate inside bounds", false, "<no player>")
		return
	p.set("demo_active", true)
	p.set("demo_dir", Vector2.LEFT)
	await _frames(12)
	p.set("demo_dir", Vector2.RIGHT)
	await _frames(30)
	p.set("demo_dir", Vector2.ZERO)
	await _frames(2)
	var room := _room_rect(_json)
	(p as Node2D).global_position = room.position + Vector2(-200.0, -200.0)
	await _frames(1)
	var raw_min: Vector2 = _stage.get("_raw_min")
	var raw_max: Vector2 = _stage.get("_raw_max")
	var mn: Vector2 = _stage.get("_min_pos")
	var mx: Vector2 = _stage.get("_max_pos")
	var final_pos: Vector2 = (p as Node2D).global_position
	var excursion: bool = not _within(room, raw_min) or not _within(room, raw_max)
	var clamped_back: bool = _within(room, final_pos)
	var raw_fail := _failures({"min_pos": raw_min, "max_pos": raw_max, "room_rect": room})
	var clamped_fail := _failures({"min_pos": mn, "max_pos": mx, "room_rect": room})
	var violating := _failures({
		"min_pos": room.position - Vector2(50, 50),
		"max_pos": room.end + Vector2(50, 50),
		"room_rect": room,
	})
	var tracked: bool = raw_min != Vector2.INF and raw_max != Vector2(-INF, -INF) \
		and mn != Vector2.INF and mx != Vector2(-INF, -INF)
	var ok: bool = tracked and excursion and clamped_back \
		and _has(raw_fail, "bounds") and clamped_fail.is_empty() and _has(violating, "bounds")
	_check("player traverses toward the gate inside bounds", ok,
		"raw=%s..%s final=%s excursion=%s clamped_back=%s raw_fail=%s clamped_fail=%s" % [
			raw_min, raw_max, final_pos, excursion, clamped_back, raw_fail, clamped_fail])


func _case_unsupported_ids_rejected() -> void:
	if _stage == null:
		_check("unsupported ids are rejected by name", false, "<no stage>")
		return
	var original_boss: Node = _stage.get("boss")
	# Negative fixture 1: an unknown map id must be rejected and leave the scene intact.
	var bad_id := _json.duplicate(true)
	bad_id["id"] = "map99"
	var reported_id: Array = _stage.call("load_map_data", bad_id)
	var rule_id := _failures({"map_id": "map99"})
	# Negative fixture 2: a future ability key must be named, never skipped.
	var bad_future := _json.duplicate(true)
	bad_future["hazards"] = [{"id": "acid_pool", "kind": "hazard_zone"}]
	var reported_future: Array = _stage.call("load_map_data", bad_future)
	var rule_future := _failures({"future_ids": ["hazards"]})
	# Negative fixture 3: an unimplemented boss with no fallback must be named.
	var bad_boss := _json.duplicate(true)
	var boss_block: Dictionary = (bad_boss.get("boss", {}) as Dictionary).duplicate(true)
	boss_block["id"] = "the_unborn"
	boss_block["fallback_until_implemented"] = null
	boss_block.erase("built_from")
	bad_boss["boss"] = boss_block
	var reported_boss: Array = _stage.call("load_map_data", bad_boss)
	var rule_boss := _failures({"boss_id": "the_unborn", "has_fallback": false})
	var still_same: bool = original_boss != null and original_boss == _stage.get("boss")
	var real: Array = _stage.call("load_map_data", _json)
	var ok: bool = _has(reported_id, "unsupported") and _has(rule_id, "unsupported") \
		and _has(reported_future, "unsupported") and _has(rule_future, "unsupported") \
		and _has(reported_boss, "unsupported") and _has(rule_boss, "unsupported") \
		and still_same and real.is_empty()
	_check("unsupported map/future/boss ids are rejected by name", ok,
		"map=%s future=%s boss=%s still_same=%s real=%s" % [
			reported_id, reported_future, reported_boss, still_same, real])


func _case_runtime_copy_drift() -> void:
	var canonical := _sha256_file(_canonical_path())
	var runtime := _sha256_file(MAP_RES)
	var copy_ok: bool = canonical != "" and runtime != "" and canonical == runtime
	var bytes := FileAccess.get_file_as_bytes(MAP_RES)
	var drifted := bytes.duplicate()
	if drifted.size() > 0:
		drifted[0] = (int(drifted[0]) + 1) % 256
	var rule := _failures({"runtime_hash": runtime, "canonical_hash": _sha256_bytes(drifted)})
	var ok: bool = copy_ok and _has(rule, "drift")
	_check("runtime copy drift is rejected", ok,
		"copy_matches=%s rule=%s canonical=%s runtime=%s" % [
			copy_ok, rule, canonical.substr(0, 12), runtime.substr(0, 12)])


func _case_demo_flag_derived_from_map_id() -> void:
	if _stage == null or not _stage.has_method("demo_flag"):
		_check("demo flag, prefix and RESULT derive from map_id", false, "no derived-flag API")
		return
	var flag := str(_stage.call("demo_flag"))
	var prefix := str(_stage.call("log_prefix"))
	var pass_line := str(_stage.call("result_line", true))
	var fail_line := str(_stage.call("result_line", false))
	var generic_ok: bool = bool(_stage.call("is_demo_arg", "--map-demo=map03"))
	var legacy_ok: bool = bool(_stage.call("is_demo_arg", "--map03-demo"))
	var other_generic: bool = bool(_stage.call("is_demo_arg", "--map-demo=map02"))
	var other_legacy: bool = bool(_stage.call("is_demo_arg", "--map02-demo"))
	var ok: bool = flag == "--map-demo=map03" and prefix == "[MAP03]" \
		and pass_line == "MAP03 RESULT: PASS" and fail_line == "MAP03 RESULT: FAIL" \
		and generic_ok and legacy_ok and not other_generic and not other_legacy
	_check("demo flag, prefix and RESULT derive from map_id", ok,
		"flag=%s prefix=%s pass=%s fail=%s generic=%s legacy=%s other=%s/%s" % [
			flag, prefix, pass_line, fail_line, generic_ok, legacy_ok,
			other_generic, other_legacy])


func _case_unknown_json_key_rejected() -> void:
	if _stage == null:
		_check("unknown SCHEMA key is rejected by name", false, "<no stage>")
		return
	var bad := _json.duplicate(true)
	bad["fission_dash"] = {"id": "stage5", "status": "Open"}
	var reported: Array = _stage.call("load_map_data", bad)
	var named := false
	for f in reported:
		if str(f).begins_with("unsupported") and str(f).find("fission_dash") != -1:
			named = true
	var real: Array = _stage.call("load_map_data", _json)
	var ok: bool = named and real.is_empty()
	_check("unknown SCHEMA key is rejected by name", ok,
		"reported=%s restored=%s" % [reported, real])


func _case_note_annotation_is_accepted() -> void:
	if _stage == null:
		_check("SCHEMA note annotation is accepted, unknown key still rejected", false, "<no stage>")
		return
	var with_note := _json.duplicate(true)
	with_note["upgrade"]["note"] = "annotation: flavour only, not a resource"
	var reported: Array = _stage.call("load_map_data", with_note)
	var unknown_still_rejected := false
	var bad := with_note.duplicate(true)
	bad["truly_unknown_key"] = {"status": "Open"}
	for f in _stage.call("load_map_data", bad):
		if str(f).begins_with("unsupported") and str(f).find("truly_unknown_key") != -1:
			unknown_still_rejected = true
	var real: Array = _stage.call("load_map_data", _json)
	var ok: bool = reported.is_empty() and unknown_still_rejected and real.is_empty()
	_check("SCHEMA note annotation is accepted, unknown key still rejected", ok,
		"note_reported=%s unknown_rejected=%s restored=%s" % [reported, unknown_still_rejected, real])


func _case_same_frame_rebuild_has_no_duplicates() -> void:
	if _stage == null:
		_check("same-frame rebuild leaves no duplicate actors", false, "<no stage>")
		return
	var first: Array = _stage.call("load_map_data", _json)
	var second: Array = _stage.call("load_map_data", _json)
	var players := 0
	var cameras := 0
	var zones := 0
	var huds := 0
	var bosses := 0
	for child in _stage.get_children():
		if child is PlayerController:
			players += 1
		elif child is Camera2D:
			cameras += 1
		elif child is EvolutionZone:
			zones += 1
		elif child is CanvasLayer:
			huds += 1
		elif child is BloomBoss or child is Predator:
			bosses += 1
	var ok: bool = first.is_empty() and second.is_empty() \
		and players == 1 and cameras == 1 and zones == 1 \
		and huds == 1 and bosses == 1
	_check("same-frame rebuild leaves no duplicate actors", ok,
		"first=%s second=%s players=%d cameras=%d zones=%d huds=%d bosses=%d" % [
			first, second, players, cameras, zones, huds, bosses])


# ------------------------------------------------------------------- entry

func _init() -> void:
	await _frames(2)
	_json = _read_json(MAP_RES)
	_stage = _make_stage()
	await _frames(3)
	await _case_runtime_json_loads()
	await _case_slabs_match_rects()
	await _case_player_at_checkpoint()
	await _case_motes_and_zone()
	await _case_gate_closed_then_open()
	await _case_boss_is_bloom()
	await _case_boss_hud_shows_real_max_health()
	await _case_burst_window()
	await _case_completion_marker()
	await _case_retry_preserves_progress()
	await _case_player_traverses_in_bounds()
	await _case_unsupported_ids_rejected()
	await _case_runtime_copy_drift()
	await _case_demo_flag_derived_from_map_id()
	await _case_unknown_json_key_rejected()
	await _case_note_annotation_is_accepted()
	await _case_same_frame_rebuild_has_no_duplicates()
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	await _frames(2)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] map03_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
