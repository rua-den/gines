extends SceneTree
## Headless rule check for the JSON-driven map runner (map01 only).
##
## Nine named cases. Each case pairs the runner's pure evaluate_map_run()
## contract with a real assertion on the instanced scene or on the map files,
## so a runner that only implements the evaluator but never builds the scene
## cannot pass. Several cases feed VIOLATING facts (so deleting a named rule
## fails) and also drive real rejection / movement (so broken integration
## fails).
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/map_runner_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 9
const MAP_RES := "res://resources/maps/map01.json"
const RUNNER_SCENE := "res://scenes/map_runner.tscn"

var _passed := 0
var _failed := 0
var _runner: Node = null
var _json: Dictionary = {}
var _eps := 0.001


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
	# Test-only: the canonical map lives outside res://. The runner never uses
	# this path (runtime copies are read from res://resources/maps/).
	return ProjectSettings.globalize_path("res://") + "../docs/maps/map01.json"


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


func _make_runner() -> Node:
	var packed: PackedScene = load(RUNNER_SCENE)
	if packed == null:
		return null
	var r: Node = packed.instantiate()
	get_root().add_child(r)
	return r


func _call_runner(method: String, arg: Variant) -> Array:
	if _runner == null or not _runner.has_method(method):
		return []
	var value: Variant = _runner.call(method, arg)
	return value if value is Array else []


func _failures(facts: Dictionary) -> Array:
	return _call_runner("evaluate_map_run", facts)


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
	return a.position.distance_to(b.position) <= _eps and a.size.distance_to(b.size) <= _eps


func _room_rect(data: Dictionary) -> Rect2:
	var room: Dictionary = data.get("room", {})
	return Rect2(0.0, 0.0, float(room.get("width", 1920)), float(room.get("height", 1080)))


func _enemy() -> Node:
	return _runner.get("enemy") if _runner != null else null


func _within(rect: Rect2, point: Vector2) -> bool:
	return point.x >= rect.position.x and point.y >= rect.position.y \
		and point.x <= rect.end.x and point.y <= rect.end.y


# ------------------------------------------------------------------- cases

func _case_runtime_json_loads() -> void:
	var parsed := _read_json(MAP_RES)
	var id_ok: bool = str(parsed.get("id", "")) == "map01"
	var obstacles: Variant = parsed.get("obstacles", [])
	var count_ok: bool = obstacles is Array and (obstacles as Array).size() == 4
	var rdata: Dictionary = {}
	if _runner != null:
		var value: Variant = _runner.get("map_data")
		if value is Dictionary:
			rdata = value
	var runner_ok: bool = _runner != null \
		and str(rdata.get("id", "")) == "map01" \
		and (rdata.get("obstacles", []) as Array).size() == 4
	var failures: Variant = _runner.get("load_failures") if _runner != null else null
	var gate_ok: bool = failures is Array and (failures as Array).is_empty()
	var ok: bool = id_ok and count_ok and runner_ok and gate_ok
	_check("runtime JSON loads and matches canonical id", ok,
		"id=%s obstacles=%s runner_id=%s gate=%s" % [
			parsed.get("id", "<none>"),
			(obstacles as Array).size() if obstacles is Array else "?",
			rdata.get("id", "<none>"), failures])


func _case_slabs_match_rects() -> void:
	var expected := _obstacle_rects(_json)
	var slabs: Variant = _runner.get("slabs") if _runner != null else null
	var ok: bool = slabs is Array and (slabs as Array).size() == expected.size()
	if ok:
		for i in expected.size():
			var body := (slabs as Array)[i] as StaticBody2D
			if body == null or body.collision_layer != 2 or not _rect_eq(_body_rect(body), expected[i]):
				ok = false
				break
	_check("slabs match JSON rects", ok,
		"expected=%d actual=%s" % [expected.size(),
			(slabs as Array).size() if slabs is Array else "<no runner>"])


func _case_player_at_checkpoint() -> void:
	var cp: Dictionary = _json.get("checkpoint", {})
	var pos: Array = cp.get("position", [])
	var expect := Vector2(float(pos[0]), float(pos[1])) if pos.size() >= 2 else Vector2(-1, -1)
	var p: Node = _runner.get("player") if _runner != null else null
	var ok: bool = expect == Vector2(300.0, 500.0) \
		and p != null and p is PlayerController \
		and is_equal_approx((p as Node2D).position.x, expect.x) \
		and is_equal_approx((p as Node2D).position.y, expect.y) \
		and not bool(p.get("evolved")) \
		and is_zero_approx(float(p.get("nutrition")))
	_check("player spawns at checkpoint", ok,
		"expect=%s actual=%s evolved=%s nutrition=%s" % [expect,
			(p as Node2D).position if p != null else "<none>",
			p.get("evolved") if p != null else "?",
			p.get("nutrition") if p != null else "?"])


func _case_boss_predator_fallback() -> void:
	var built_from := str((_json.get("boss", {}) as Dictionary).get("built_from", ""))
	var enemy := _enemy()
	var ok: bool = built_from == "Predator" and enemy != null \
		and enemy is Predator and not (enemy is BloomBoss)
	_check("planned boss uses Predator fallback", ok,
		"built_from=%s enemy=%s" % [built_from,
			enemy.get_script().get_global_name() if enemy != null and enemy.get_script() != null else "<none>"])


func _case_missing_built_from() -> void:
	var bad := _json.duplicate(true)
	var boss: Dictionary = bad.get("boss", {}).duplicate(true)
	boss.erase("built_from")
	bad["boss"] = boss
	var original := _enemy()
	var reported: Array = _call_runner("load_map_data", bad)
	var rule := _failures({"boss_built_from": ""})
	var still_same: bool = original != null and original == _enemy() and original is Predator
	var ok: bool = _has(reported, "no executable fallback") \
		and _has(rule, "no executable fallback") and still_same
	_check("missing built_from is rejected", ok,
		"reported=%s rule=%s enemy_unchanged=%s" % [reported, rule, still_same])


func _case_unsupported_map_id() -> void:
	var bad := _json.duplicate(true)
	bad["id"] = "map99"
	var original := _enemy()
	var reported: Array = _call_runner("load_map_data", bad)
	var rule := _failures({"map_id": "map99"})
	var still_same: bool = original != null and original == _enemy() and original is Predator
	var ok: bool = _has(reported, "unsupported") and _has(rule, "unsupported") and still_same
	_check("unsupported map id is rejected", ok,
		"reported=%s rule=%s enemy_unchanged=%s" % [reported, rule, still_same])


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


func _case_player_in_bounds() -> void:
	if _runner == null:
		_check("player stays inside room bounds", false, "<no runner>")
		return
	var p: Node = _runner.get("player")
	if p == null or not (p is Node2D):
		_check("player stays inside room bounds", false, "<no player>")
		return
	p.set("demo_active", true)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		p.set("demo_dir", dir)
		await _frames(12)
	p.set("demo_dir", Vector2.ZERO)
	await _frames(2)
	# Force a real excursion OUTSIDE the room, then let one frame run. The
	# runner records raw (pre-clamp) and clamped (post-clamp) extremes; only the
	# raw pair may violate the room. Breaking the clamp leaves the final body
	# outside, so this case fails instead of silently passing.
	var room := _room_rect(_json)
	(p as Node2D).global_position = room.position + Vector2(-200.0, -200.0)
	await _frames(1)
	var raw_min: Vector2 = _runner.get("_raw_min")
	var raw_max: Vector2 = _runner.get("_raw_max")
	var mn: Vector2 = _runner.get("_min_pos")
	var mx: Vector2 = _runner.get("_max_pos")
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
		and _has(raw_fail, "bounds") and clamped_fail.is_empty() \
		and _has(violating, "bounds")
	_check("player stays inside room bounds", ok,
		"raw=%s..%s final=%s clamped=%s..%s excursion=%s clamped_back=%s raw_fail=%s clamped_fail=%s violating=%s" % [
			raw_min, raw_max, final_pos, mn, mx, excursion, clamped_back,
			raw_fail, clamped_fail, violating])


func _case_future_ids_rejected() -> void:
	var bad := _json.duplicate(true)
	var upgrade: Dictionary = (bad.get("upgrade", {}) as Dictionary).duplicate(true)
	upgrade["grants"] = ["surface_grip", "dash"]
	bad["upgrade"] = upgrade
	bad["hazards"] = [{"id": "acid_pool", "kind": "hazard_zone"}]
	var original := _enemy()
	var reported: Array = _call_runner("load_map_data", bad)
	var rule := _failures({
		"upgrade_grants": ["dash"],
		"future_ids": ["hazards"],
	})
	var grant_named := _has(reported, "unsupported") and _has(rule, "unsupported")
	var still_same: bool = original != null and original == _enemy() and original is Predator
	# Real map01 has only implemented grants and no future-id keys: no false positive.
	var real_fail: Array = _call_runner("load_map_data", _json)
	var ok: bool = grant_named and still_same and real_fail.is_empty()
	_check("future grants and hazard ids are rejected", ok,
		"reported=%s rule=%s real=%s enemy_unchanged=%s" % [
			reported, rule, real_fail, still_same])


# ------------------------------------------------------------------- entry

func _init() -> void:
	await _frames(2)
	_json = _read_json(MAP_RES)
	_runner = _make_runner()
	await _frames(3)
	await _case_runtime_json_loads()
	await _case_slabs_match_rects()
	await _case_player_at_checkpoint()
	await _case_boss_predator_fallback()
	await _case_missing_built_from()
	await _case_unsupported_map_id()
	await _case_runtime_copy_drift()
	await _case_player_in_bounds()
	await _case_future_ids_rejected()
	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()
	await _frames(2)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] map_runner_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
