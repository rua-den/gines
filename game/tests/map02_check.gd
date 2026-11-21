extends SceneTree
## Headless rule check for the parameterized map02 stage ("The Divide").
##
## Nineteen named cases, mirroring map03_check.gd. Each case pairs the stage's
## pure evaluate_map_stage() contract with a real assertion on the instanced
## scene or on the map files. map02 differs from map03 in three honest ways:
##   - all four obstacles are static_slab (there is NO gate obstacle), so the
##     "gate" is the logical evolution flag only;
##   - the boss is the planned `the_splitter`, resolved through the documented
##     built_from -> Predator fallback (a Proposed placeholder, not approved);
##   - the signature geometry is two divider walls, so the traversal case
##     drives the player through both slits instead of toward a gate slab.
## For the Predator fallback there is no weak-window phase (that belongs to
## BloomBoss), so the burst case keeps the pure window rule falsifiable and
## asserts the real fallback takes exactly one damage per burst.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/map02_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 19
const MAP_RES := "res://resources/maps/map02.json"
const STAGE_SCENE := "res://scenes/map02.tscn"
const EXPECTED_ID := "map02"
const EXPECTED_OBSTACLES := 4
const EXPECTED_MOTES := 3
const CHECKPOINT := Vector2(320.0, 520.0)
const BOSS_X := 1560.0
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
	return ProjectSettings.globalize_path("res://") + "../docs/maps/map02.json"


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


func _obstacle_kinds(data: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	var obstacles: Array = data.get("obstacles", [])
	for o in obstacles:
		if o is Dictionary:
			kinds.append(str((o as Dictionary).get("kind", "")))
	return kinds


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
func _prepare_burst(p: Node, boss_pos: Vector2) -> void:
	p.set("evolved", true)
	p.set("dead", false)
	p.set("energy", float(p.get("MAX_ENERGY")))
	p.set("_burst_cooldown", 0.0)
	(p as Node2D).global_position = boss_pos + Vector2(-90.0, 0.0)


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
	_check("slabs match every JSON rect (all static_slab)", ok,
		"expected=%d actual=%s" % [expected.size(),
			(slabs as Array).size() if slabs is Array else "<no stage>"])


func _case_player_at_checkpoint() -> void:
	var cp: Dictionary = _json.get("checkpoint", {})
	var pos: Array = cp.get("position", [])
	var expect := Vector2(float(pos[0]), float(pos[1])) if pos.size() >= 2 else Vector2(-1, -1)
	var p: Node = _stage.get("player") if _stage != null else null
	var ok: bool = expect == CHECKPOINT \
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
		"zone_before_gate": zone != null and (zone as Node2D).global_position.x < BOSS_X,
	})
	var ok: bool = count == EXPECTED_MOTES \
		and is_equal_approx(total, PlayerController.EVOLVE_COST) \
		and zone is EvolutionZone \
		and (zone as Node2D).global_position.x < BOSS_X \
		and not _has(rule_ok, "progression")
	var bad := _failures({
		"mote_nutrition": PlayerController.EVOLVE_COST - 10.0,
		"evolve_cost": PlayerController.EVOLVE_COST,
		"zone_before_gate": true,
	})
	ok = ok and _has(bad, "progression")
	_check("three motes pay for evolution; zone is before the boss", ok,
		"motes=%d nutrition=%.0f cost=%.0f zone=%s rules=%s" % [
			count, total, PlayerController.EVOLVE_COST,
			zone.global_position if zone != null else "<none>", rule_ok])


func _case_gate_closed_then_open() -> void:
	# map02 has no gate obstacle; every obstacle is a static_slab. The stage
	# therefore builds no physical gate slab and `gate_open()` is driven purely
	# by player.evolved. Both facts are asserted here.
	var kinds := _obstacle_kinds(_json)
	var json_has_gate: bool = kinds.has("gate")
	var gate := _stage.get("gate") as StaticBody2D if _stage != null else null
	var no_gate_slab: bool = gate == null
	var closed_before: bool = not json_has_gate and no_gate_slab and _stage != null \
		and not bool(_stage.call("gate_open"))
	var p: Node = _stage.get("player") if _stage != null else null
	var evolved := false
	if p != null:
		p.set("nutrition", float(p.get("EVOLVE_COST")))
		evolved = bool(p.call("evolve"))
	await _frames(1)
	var open_after: bool = bool(_stage.call("gate_open"))
	var bad := _failures({"evolved": true, "gate_open": false})
	var good := _failures({"evolved": true, "gate_open": true})
	var early := _failures({"evolved": false, "gate_open": true})
	var ok: bool = no_gate_slab and not json_has_gate and closed_before \
		and evolved and open_after \
		and _has(bad, "gate") and not _has(good, "gate") and _has(early, "gate")
	_check("no gate slab; logical gate closed then open", ok,
		"json_gate=%s slab=%s closed_before=%s evolved=%s open_after=%s rules=%s/%s/%s" % [
			json_has_gate, no_gate_slab, closed_before, evolved, open_after, bad, good, early])


func _case_boss_is_predator() -> void:
	var boss: Node = _stage.get("boss") if _stage != null else null
	var boss_id := str((_json.get("boss", {}) as Dictionary).get("id", ""))
	var with_fallback := _failures({"boss_id": boss_id, "has_fallback": true})
	var without_fallback := _failures({"boss_id": boss_id, "has_fallback": false})
	var is_placeholder: bool = boss != null and bool(boss.get_meta("placeholder", false))
	var expected_label := "one Predator stands in for The Splitter; division is planned"
	var label := str(boss.get_meta("fallback_label", "")) if boss != null else ""
	var ok: bool = boss_id == "the_splitter" and boss is Predator \
		and int(boss.get("health")) == Predator.MAX_HEALTH \
		and not is_placeholder \
		and str(boss.get_meta("boss_id", "")) == "the_splitter" \
		and label == expected_label \
		and with_fallback.is_empty() and _has(without_fallback, "unsupported")
	_check("planned boss id resolves to built_from Predator", ok,
		"boss_id=%s boss=%s health=%s meta=%s placeholder=%s label=%s with_fb=%s without_fb=%s" % [
			boss_id,
			boss.get_script().get_global_name() if boss != null and boss.get_script() != null else "<none>",
			boss.get("health") if boss != null else "?",
			boss.get_meta("boss_id", "") if boss != null else "?",
			is_placeholder, label, with_fallback, without_fallback])


func _case_burst_window() -> void:
	# The pure rule stays falsifiable: outside != 0 and inside != 1 are named.
	# The Predator fallback has no weak-window phase, so a real burst always
	# deals exactly one; weak-window gating belongs to the implemented BloomBoss.
	var outside_rule := _failures({"outside_damage": 1})
	var inside_rule := _failures({"inside_damage": 0})
	var boss := _stage.get("boss") as Predator if _stage != null else null
	var p: Node = _stage.get("player") if _stage != null else null
	var dealt := -1
	var fired := false
	if boss != null and p != null:
		boss.health = Predator.MAX_HEALTH
		boss.defeated = false
		_prepare_burst(p, (boss as Node2D).global_position)
		var before := int(boss.health)
		fired = bool(p.call("spike_burst"))
		dealt = before - int(boss.health)
	var ok: bool = _has(outside_rule, "burst-outside") and _has(inside_rule, "burst-inside") \
		and fired and dealt == 1
	_check("burst rule falsifiable; fallback takes exactly 1", ok,
		"fired=%s dealt=%d rules=%s/%s" % [fired, dealt, outside_rule, inside_rule])


func _case_completion_marker() -> void:
	var marker_before: bool = _stage.has_node("CompletionMarker") if _stage != null else true
	var boss := _stage.get("boss") as Predator if _stage != null else null
	if boss != null:
		boss.health = Predator.MAX_HEALTH
		boss.defeated = false
		boss.take_damage(Predator.MAX_HEALTH)
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
		"boss_max_health": Predator.MAX_HEALTH,
	}
	var good := _failures(facts)
	var bad := _failures({
		"evolved": false, "nutrition": -1.0,
		"boss_health": 1, "boss_max_health": Predator.MAX_HEALTH,
	})
	var at_shelter: bool = p != null \
		and is_equal_approx((p as Node2D).global_position.x, CHECKPOINT.x) \
		and is_equal_approx((p as Node2D).global_position.y, CHECKPOINT.y)
	var ok: bool = evolved_before and bool(facts["evolved"]) \
		and is_equal_approx(float(facts["nutrition"]), nutrition_before) \
		and int(facts["boss_health"]) == Predator.MAX_HEALTH \
		and at_shelter and not _has(good, "retry") and _has(bad, "retry")
	_check("shelter retry keeps progress and resets the boss", ok,
		"evolved=%s nutrition=%.0f boss_hp=%d at_shelter=%s failures=%s" % [
			facts["evolved"], float(facts["nutrition"]), int(facts["boss_health"]),
			at_shelter, good])


func _case_player_traverses_in_bounds() -> void:
	if _stage == null:
		_check("player crosses both divider slits inside bounds", false, "<no stage>")
		return
	var p: Node = _stage.get("player")
	if p == null or not (p is Node2D):
		_check("player crosses both divider slits inside bounds", false, "<no player>")
		return
	p.set("demo_active", true)
	p.set("dead", false)
	p.set("health", 99) # isolate geometry from the placeholder boss's contact damage
	# The left divider (x 700..780) blocks y 300..980: cross through its top
	# slit at y < 245 while sliding up its left face.
	(p as Node2D).global_position = CHECKPOINT
	p.set("demo_dir", Vector2(0.55, -0.84).normalized())
	var crossed_left := false
	for i in 420:
		await physics_frame
		if (p as Node2D).global_position.x > 820.0:
			crossed_left = true
			break
	# The right divider (x 1280..1360) blocks y 60..760: cross through its
	# lower slit at y > 815 while sliding down its left face.
	p.set("demo_dir", Vector2(0.72, 0.69).normalized())
	var crossed_right := false
	for i in 480:
		await physics_frame
		if (p as Node2D).global_position.x > 1420.0:
			crossed_right = true
			break
	p.set("demo_dir", Vector2.ZERO)
	await _frames(2)
	var room := _room_rect(_json)
	var final_pos: Vector2 = (p as Node2D).global_position
	(p as Node2D).global_position = room.position + Vector2(-200.0, -200.0)
	await _frames(1)
	var raw_min: Vector2 = _stage.get("_raw_min")
	var raw_max: Vector2 = _stage.get("_raw_max")
	var mn: Vector2 = _stage.get("_min_pos")
	var mx: Vector2 = _stage.get("_max_pos")
	final_pos = (p as Node2D).global_position
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
	var ok: bool = crossed_left and crossed_right and tracked and excursion \
		and clamped_back and _has(raw_fail, "bounds") and clamped_fail.is_empty() \
		and _has(violating, "bounds")
	_check("player crosses both divider slits inside bounds", ok,
		"left=%s right=%s raw=%s..%s final=%s excursion=%s clamped=%s" % [
			crossed_left, crossed_right, raw_min, raw_max, final_pos,
			excursion, clamped_back])


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
	var generic_ok: bool = bool(_stage.call("is_demo_arg", "--map-demo=map02"))
	var legacy_ok: bool = bool(_stage.call("is_demo_arg", "--map02-demo"))
	var other_generic: bool = bool(_stage.call("is_demo_arg", "--map-demo=map03"))
	var other_legacy: bool = bool(_stage.call("is_demo_arg", "--map03-demo"))
	var ok: bool = flag == "--map-demo=map02" and prefix == "[MAP02]" \
		and pass_line == "MAP02 RESULT: PASS" and fail_line == "MAP02 RESULT: FAIL" \
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


# --------------------------------------------------- failure-capable demo cases

func _case_demo_verdict_can_fail() -> void:
	# Run the real demo in a subprocess with bursts suppressed (energy held at
	# 0). It must report FAIL, exit 1, name the suppressed-burst failure and
	# emit NO GDScript error. Reverting the typed-defeat/attack patch restores
	# the `bool(null)` script error, so this case can genuinely fail.
	# The subprocess cwd is the project dir, so pass an absolute --path.
	var args := PackedStringArray([
		"--headless", "--audio-driver", "Dummy",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://scenes/map02.tscn", "--", "--map02-demo",
		"--map-demo-zero-energy",
	])
	var output: Array = []
	var out_code := -1
	var returned := OS.execute(OS.get_executable_path(), args, output, true, out_code)
	# On this Godot build the return value holds the child exit code while the
	# out-parameter stays -1; accept either so the assertion stays portable.
	var child_exit: int = out_code if out_code >= 0 else int(returned)
	var text := ""
	for line in output:
		text += str(line) + "\n"
	var has_fail_line: bool = text.find("MAP02 RESULT: FAIL") != -1
	var has_named: bool = text.find("bursts suppressed (energy=0)") != -1
	var no_script_error: bool = text.find("SCRIPT ERROR") == -1
	var ok: bool = child_exit == 1 and has_fail_line and has_named and no_script_error
	_check("suppressed-burst demo FAILs by name, no script error", ok,
		"returned=%d out=%d exit=%d fail_line=%s named=%s no_script_error=%s" % [
			int(returned), out_code, child_exit, has_fail_line, has_named,
			no_script_error])


func _case_demo_verdict_requires_zero_boss_health() -> void:
	if _stage == null or not _stage.has_method("evaluate_demo"):
		_check("demo verdict requires boss at zero health", false, "no evaluate_demo API")
		return
	var facts := {
		"map_id": EXPECTED_ID,
		"evolved": true,
		"gate_open": true,
		"completion_count": 1,
		"boss_defeated": true,
		"boss_type": "Predator",
		"boss_health": 1,
		"bursts": 2,
		"nutrition": 0.0,
	}
	var bad: Array = _stage.call("evaluate_demo", facts)
	facts["boss_health"] = 0
	var good: Array = _stage.call("evaluate_demo", facts)
	var boss: Node = _stage.get("boss")
	var real_health := int(boss.get("health")) if boss != null else -1
	var real_facts: Dictionary = _stage.call("_demo_facts")
	var ok: bool = _has(bad, "completion") and good.is_empty() \
		and int(real_facts.get("boss_health", -2)) == real_health \
		and str(real_facts.get("boss_type", "")) == "Predator"
	_check("demo verdict requires boss at zero health", ok,
		"bad=%s good=%s real_health=%d facts_health=%s boss_type=%s" % [
			bad, good, real_health, real_facts.get("boss_health", "<none>"),
			real_facts.get("boss_type", "<none>")])


func _case_live_predator_no_false_defeat() -> void:
	if _stage == null or not _stage.has_method("boss_is_defeated"):
		_check("live Predator is never falsely reported defeated", false, "no typed defeat API")
		return
	var boss := _stage.get("boss") as Predator
	if boss == null:
		_check("live Predator is never falsely reported defeated", false, "<no Predator boss>")
		return
	# The Predator exposes `defeated`, NOT `is_defeated`. A typed check must
	# treat the missing property as ALIVE without a bool(null) script error.
	boss.health = Predator.MAX_HEALTH
	boss.defeated = false
	var live: bool = bool(_stage.call("boss_is_defeated"))
	var stage_before := int(_stage.get("_demo_stage"))
	_stage.set("_demo", true)
	_stage.call("_demo_combat")
	var still_in_combat: bool = int(_stage.get("_demo_stage")) == stage_before
	_stage.set("_demo", false)
	var label := str(boss.get_meta("fallback_label", ""))
	var expected_label := "one Predator stands in for The Splitter; division is planned"
	var ok: bool = not live and still_in_combat and label == expected_label
	_check("live Predator is never falsely reported defeated", ok,
		"live=%s stage=%d->%d label=%s" % [
			live, stage_before, int(_stage.get("_demo_stage")), label])


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
	await _case_boss_is_predator()
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
	await _case_demo_verdict_can_fail()
	await _case_demo_verdict_requires_zero_boss_health()
	await _case_live_predator_no_false_defeat()
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	await _frames(2)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] map02_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
