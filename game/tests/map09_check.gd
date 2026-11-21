extends SceneTree
## Headless rule check for map09 ("The Convergence") and its FinalBoss.
##
## The ninth map is a genuinely distinct encounter, not a retuned Rot Bloom:
##   - `FinalBoss extends BloomBoss`, 12 HP, phase-1 timings 0.6 / 1.5, and a
##     `second_wind` at <= 6 HP with 0.45 / 1.1 timings plus a readable marker
##     on `phase_changed`. Damage is still accepted only while exposed and
##     `defeated` still fires once.
##   - `the_convergence` is an IMPLEMENTED boss resolved by MapStage to
##     FinalBoss (never a placeholder). `final_form` is a PLANNED upgrade whose
##     `integrated_form` grant loads through the two-tier fallback mechanism.
##   - The final membrane is a planned gate built as an inert slab. It signposts
##     birth; no birth cinematic, combo input or new resource is invented.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/map09_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 19
const MAP_RES := "res://resources/maps/map09.json"
const BOSS_SCRIPT := "res://scripts/final_boss.gd"
const STAGE_SCENE := "res://scenes/map09.tscn"
const EXPECTED_ID := "map09"
const EXPECTED_OBSTACLES := 6
const EXPECTED_MOTES := 3
const CHECKPOINT := Vector2(300.0, 520.0)
const GATE_LEFT_X := 1500.0
const GATE_END_X := 1540.0
const BOSS_X := 1760.0
const ZONE_X := 1080.0
const EPS := 0.001

# Literal expectations from the design brief — never derived from the code under test.
const WANT_MAX_HEALTH := 12
const WANT_SECOND_WIND_HEALTH := 6
const WANT_TELEGRAPH_1 := 0.6
const WANT_WEAK_1 := 1.5
const WANT_TELEGRAPH_2 := 0.45
const WANT_WEAK_2 := 1.1

# Mirrors the capability sets declared in map_stage.gd (drift is caught below).
const SUPPORTED := ["surface_grip", "crawl", "absorption_channel", "spike_ring",
	"spike_burst", "energy_pool", "nutrition"]
const PLANNED := ["body_contraction", "dash", "run", "jump", "body_part_strike",
	"double_jump", "glide", "chemical_veil", "integrated_form", "combo_mastery"]

var _passed := 0
var _failed := 0
var _stage: MapStage = null
var _json: Dictionary = {}


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-48s %s" % ["PASS" if ok else "FAIL", label, detail])


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
	# Test-only: the canonical map lives outside res://. The stage never uses it.
	return ProjectSettings.globalize_path("res://") + "../docs/maps/map09.json"


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


func _make_stage() -> MapStage:
	var packed: PackedScene = load(STAGE_SCENE)
	if packed == null:
		return null
	var s: MapStage = packed.instantiate() as MapStage
	get_root().add_child(s)
	return s


func _boss_script() -> Variant:
	return load(BOSS_SCRIPT)


func _make_final_boss() -> Variant:
	var script: Variant = _boss_script()
	if script == null:
		return null
	var boss: Variant = (script as GDScript).new()
	if boss == null:
		return null
	get_root().add_child(boss)
	return boss


func _dispose_boss(boss: Variant) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	(boss as Node).queue_free()


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


func _prepare_burst(p: Node, boss: Node) -> void:
	p.set("evolved", true)
	p.set("dead", false)
	p.set("energy", float(p.get("MAX_ENERGY")))
	p.set("_burst_cooldown", 0.0)
	(p as Node2D).global_position = (boss as Node2D).global_position + Vector2(-90.0, 0.0)


# ------------------------------------------------------------ FinalBoss cases

func _case_final_boss_has_twelve_health() -> void:
	var script: Variant = _boss_script()
	var boss: Variant = _make_final_boss()
	if script == null or boss == null:
		_check("FinalBoss starts at 12 health", false, "missing FinalBoss script")
		return
	var consts: Dictionary = (script as GDScript).get_script_constant_map()
	var declared: int = int(consts.get("FINAL_MAX_HEALTH", -1))
	var accessor: int = int(boss.call("max_health"))
	var ok: bool = declared == WANT_MAX_HEALTH and accessor == WANT_MAX_HEALTH \
		and int(boss.get("health")) == WANT_MAX_HEALTH \
		and not bool(boss.get("is_defeated"))
	_check("FinalBoss starts at 12 health", ok,
		"declared=%d accessor=%d health=%s defeated=%s" % [
			declared, accessor, boss.get("health"), boss.get("is_defeated")])
	_dispose_boss(boss)
	await _frames(2)


func _case_phase_one_timings() -> void:
	var boss: Variant = _make_final_boss()
	if boss == null:
		_check("phase 1 uses the learned 0.6 / 1.5 rhythm", false, "missing FinalBoss")
		return
	var telegraph: float = float(boss.call("telegraph_duration"))
	var weak: float = float(boss.call("weak_window_duration"))
	var ok: bool = is_equal_approx(telegraph, WANT_TELEGRAPH_1) \
		and is_equal_approx(weak, WANT_WEAK_1) \
		and not bool(boss.get("second_wind"))
	_check("phase 1 uses the learned 0.6 / 1.5 rhythm", ok,
		"telegraph=%.2f weak=%.2f second_wind=%s" % [
			telegraph, weak, boss.get("second_wind")])
	_dispose_boss(boss)
	await _frames(2)


func _case_second_wind_at_half_health() -> void:
	var boss: Variant = _make_final_boss()
	if boss == null:
		_check("second wind at <=6 HP with 0.45 / 1.1 and marker", false, "missing FinalBoss")
		return
	var labels: Array[String] = []
	boss.connect("phase_changed", func(label: String) -> void: labels.append(label))
	# Six points of damage take 12 -> 6: exactly the second-wind threshold.
	boss.set("phase", "exposed")
	var landed: bool = bool(boss.call("take_damage", WANT_MAX_HEALTH - WANT_SECOND_WIND_HEALTH))
	var health_after: int = int(boss.get("health"))
	var in_wind: bool = bool(boss.get("second_wind"))
	var telegraph: float = float(boss.call("telegraph_duration"))
	var weak: float = float(boss.call("weak_window_duration"))
	var marked: bool = labels.has("second_wind")
	# The readable marker also rides on subsequent phase labels.
	boss.set("phase", "telegraph")
	await _frames(1)
	var labelled := false
	for label in labels:
		if str(label).find("second_wind") != -1 and str(label) != "second_wind":
			labelled = true
	var ok: bool = landed and health_after == WANT_SECOND_WIND_HEALTH and in_wind \
		and is_equal_approx(telegraph, WANT_TELEGRAPH_2) \
		and is_equal_approx(weak, WANT_WEAK_2) and marked and labelled
	_check("second wind at <=6 HP with 0.45 / 1.1 and marker", ok,
		"landed=%s hp=%d wind=%s telegraph=%.2f weak=%.2f emitted=%s labelled=%s" % [
			landed, health_after, in_wind, telegraph, weak, labels, labelled])
	_dispose_boss(boss)
	await _frames(2)


func _case_damage_only_while_exposed() -> void:
	var boss: Variant = _make_final_boss()
	if boss == null:
		_check("FinalBoss accepts damage only while exposed", false, "missing FinalBoss")
		return
	boss.set("phase", "telegraph")
	var outside: bool = bool(boss.call("take_damage", 1))
	var hp_outside: int = int(boss.get("health"))
	boss.set("phase", "exposed")
	var inside: bool = bool(boss.call("take_damage", 1))
	var hp_inside: int = int(boss.get("health"))
	var ok: bool = not outside and hp_outside == WANT_MAX_HEALTH \
		and inside and hp_inside == WANT_MAX_HEALTH - 1
	_check("FinalBoss accepts damage only while exposed", ok,
		"outside=%s hp=%d inside=%s hp=%d" % [outside, hp_outside, inside, hp_inside])
	_dispose_boss(boss)
	await _frames(2)


func _case_defeat_emitted_once() -> void:
	var boss: Variant = _make_final_boss()
	if boss == null:
		_check("FinalBoss emits defeated exactly once", false, "missing FinalBoss")
		return
	var emissions := [0]
	boss.connect("defeated", func() -> void: emissions[0] += 1)
	boss.set("health", 1)
	boss.set("phase", "exposed")
	var first: bool = bool(boss.call("take_damage", 1))
	var second: bool = bool(boss.call("take_damage", 1))
	var ok: bool = first and not second and emissions[0] == 1 \
		and bool(boss.get("is_defeated")) and int(boss.get("health")) == 0
	_check("FinalBoss emits defeated exactly once", ok,
		"first=%s second=%s emissions=%d defeated=%s hp=%s" % [
			first, second, emissions[0], boss.get("is_defeated"), boss.get("health")])
	_dispose_boss(boss)
	await _frames(2)


# --------------------------------------------------------------- map09 cases

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
	_check("slabs match every JSON rect (incl. gate slab)", ok,
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
	var before_zone := true
	var zone_x := (zone as Node2D).global_position.x if zone is Node2D else -1.0
	if motes is Array:
		for m in (motes as Array):
			if m is Absorbable:
				count += 1
				total += float(m.get("nutrition_value"))
				if (m as Node2D).global_position.x >= zone_x:
					before_zone = false
	var rule_ok := _failures({
		"mote_nutrition": total,
		"evolve_cost": PlayerController.EVOLVE_COST,
		"zone_before_gate": zone != null and zone_x < GATE_LEFT_X and zone_x < BOSS_X,
	})
	var ok: bool = count == EXPECTED_MOTES \
		and is_equal_approx(total, PlayerController.EVOLVE_COST) \
		and zone is EvolutionZone \
		and zone_x < GATE_LEFT_X and zone_x < BOSS_X and before_zone \
		and not _has(rule_ok, "progression")
	var bad := _failures({
		"mote_nutrition": PlayerController.EVOLVE_COST - 10.0,
		"evolve_cost": PlayerController.EVOLVE_COST,
		"zone_before_gate": true,
	})
	ok = ok and _has(bad, "progression")
	_check("three motes pay for evolution; zone before gate/boss", ok,
		"motes=%d nutrition=%.0f cost=%.0f zone_x=%.0f before=%s rules=%s" % [
			count, total, PlayerController.EVOLVE_COST, zone_x, before_zone, rule_ok])


func _case_convergence_membrane_closed_then_open() -> void:
	if _stage == null:
		_check("convergence membrane is a planned gate; closed then open", false, "<no stage>")
		return
	var gate_obstacle: Dictionary = {}
	for o in _json.get("obstacles", []):
		if o is Dictionary and str((o as Dictionary).get("kind", "")) == "gate":
			gate_obstacle = o
			break
	var json_has_gate: bool = not gate_obstacle.is_empty()
	var gate_id := str(gate_obstacle.get("id", ""))
	var gate_status := str(gate_obstacle.get("engine_status", ""))
	var gate_fallback := str(gate_obstacle.get("fallback_until_implemented", ""))
	var gate := _stage.get("gate") as StaticBody2D
	var p: Node = _stage.get("player")
	var placeholder_ok: bool = json_has_gate and gate_id == "convergence_membrane" \
		and gate_status == "planned" and not gate_fallback.is_empty() \
		and gate is StaticBody2D \
		and _stage.get_node_or_null("BirthCinematic") == null \
		and _stage.get_node_or_null("Birth") == null
	var complete_text := str(_stage.get("complete_text"))
	var honest_text: bool = complete_text.begins_with("MAP09 COMPLETE") \
		and complete_text.find("birth cinematic is Open") != -1 \
		and complete_text.find("birth sequence implemented") == -1 \
		and complete_text.find("birth implemented") == -1
	var closed_before: bool = gate != null and int(gate.collision_layer) == 2 \
		and gate.visible and not bool(_stage.call("gate_open"))
	var blocked := false
	if p != null and gate != null:
		p.set("demo_active", true)
		p.set("velocity", Vector2.ZERO)
		(p as Node2D).global_position = Vector2(GATE_LEFT_X - 120.0, CHECKPOINT.y)
		p.set("demo_dir", Vector2.RIGHT)
		for i in 120:
			await physics_frame
		blocked = (p as Node2D).global_position.x < GATE_LEFT_X - 40.0
	p.set("demo_dir", Vector2.ZERO)
	if p != null:
		p.set("nutrition", float(p.get("EVOLVE_COST")))
		p.call("evolve")
	await _frames(1)
	var open_after: bool = bool(_stage.call("gate_open")) \
		and gate != null and int(gate.collision_layer) == 0 and not gate.visible
	var passed := false
	if p != null:
		p.set("demo_dir", Vector2.RIGHT)
		for i in 300:
			await physics_frame
			if (p as Node2D).global_position.x > GATE_END_X + 90.0:
				passed = true
				break
	p.set("demo_dir", Vector2.ZERO)
	var bad := _failures({"evolved": true, "gate_open": false})
	var good := _failures({"evolved": true, "gate_open": true})
	var early := _failures({"evolved": false, "gate_open": true})
	var ok: bool = placeholder_ok and honest_text and closed_before and blocked \
		and open_after and passed \
		and _has(bad, "gate") and not _has(good, "gate") and _has(early, "gate")
	_check("convergence membrane is a planned gate; closed then open", ok,
		"id=%s status=%s placeholder=%s text_ok=%s closed=%s blocked=%s open=%s passed=%s rules=%s/%s/%s" % [
			gate_id, gate_status, placeholder_ok, honest_text, closed_before, blocked,
			open_after, passed, bad, good, early])


func _case_planned_grant_via_two_tier() -> void:
	if _stage == null:
		_check("final_form grant loads via the two-tier mechanism", false, "<no stage>")
		return
	var placeholder: Variant = _stage.get("placeholder_grants")
	var upgrade: Dictionary = _json.get("upgrade", {})
	var json_grants: Array = upgrade.get("grants", [])
	var json_status := str(upgrade.get("engine_status", ""))
	var json_fallback := str(upgrade.get("fallback_until_implemented", ""))
	var expected_planned: Array[String] = []
	for g in json_grants:
		if PLANNED.has(str(g)):
			expected_planned.append(str(g))
	var exact: bool = placeholder is Array \
		and (placeholder as Array).size() == expected_planned.size()
	if exact:
		for i in expected_planned.size():
			if str((placeholder as Array)[i]) != expected_planned[i]:
				exact = false
				break
	var disjoint := true
	if placeholder is Array:
		for g in (placeholder as Array):
			if SUPPORTED.has(str(g)):
				disjoint = false
	var marker_text := ""
	for child in _stage.get_children():
		if child is CanvasLayer:
			for c in child.get_children():
				if c is Label and str((c as Label).text).begins_with("PLANNED FALLBACK:"):
					marker_text = str((c as Label).text)
	var honest := not marker_text.is_empty()
	for id in expected_planned:
		honest = honest and marker_text.find(id) != -1
	var result_pass := str(_stage.call("result_line", true))
	var result_honest := result_pass == "MAP09 RESULT: PASS (placeholder)"
	var original_ack: Array = (_stage.get("acknowledged_planned_grants") as Array).duplicate()
	var a := _json.duplicate(true)
	(a["upgrade"] as Dictionary)["engine_status"] = "implemented"
	var ra: Array = _stage.call("load_map_data", a)
	var b := _json.duplicate(true)
	(b["upgrade"] as Dictionary)["fallback_until_implemented"] = ""
	var rb: Array = _stage.call("load_map_data", b)
	var c := _json.duplicate(true)
	var cg: Array = ((c["upgrade"] as Dictionary)["grants"] as Array).duplicate()
	cg.append("fission_dash")
	(c["upgrade"] as Dictionary)["grants"] = cg
	var rc: Array = _stage.call("load_map_data", c)
	_stage.set("acknowledged_planned_grants", [] as Array[String])
	var rd: Array = _stage.call("load_map_data", _json)
	_stage.set("acknowledged_planned_grants", original_ack)
	var restored: Array = _stage.call("load_map_data", _json)
	var ok: bool = str(upgrade.get("id", "")) == "final_form" \
		and json_status == "planned" and not json_fallback.is_empty() \
		and expected_planned == ["integrated_form"] and exact and disjoint and honest \
		and result_honest and _has(ra, "placeholder") and _has(rb, "placeholder") \
		and _has(rc, "unsupported") and _has(rd, "placeholder") and restored.is_empty()
	_check("final_form grant loads via the two-tier mechanism", ok,
		"id=%s placeholder=%s expected=%s disjoint=%s marker='%s' result='%s' neg=%s/%s/%s/%s restored=%s" % [
			upgrade.get("id", "<none>"), placeholder, expected_planned, disjoint,
			marker_text, result_pass, ra, rb, rc, rd, restored])


func _case_boss_is_final_boss_class() -> void:
	if _stage == null:
		_check("boss resolves to FinalBoss, not a placeholder", false, "<no stage>")
		return
	var boss: Node = _stage.get("boss")
	var boss_block: Dictionary = _json.get("boss", {})
	var boss_id := str(boss_block.get("id", ""))
	var engine_status := str(boss_block.get("engine_status", ""))
	var global_name := ""
	if boss != null and boss.get_script() != null:
		global_name = str(boss.get_script().get_global_name())
	var no_label: bool = boss != null and boss.get_node_or_null("PlaceholderLabel") == null
	var with_fallback := _failures({"boss_id": boss_id, "has_fallback": false})
	var ok: bool = boss_id == "the_convergence" and engine_status == "implemented" \
		and global_name == "FinalBoss" and boss is BloomBoss \
		and int(boss.get("health")) == WANT_MAX_HEALTH \
		and str(boss.get_meta("boss_id", "")) == boss_id \
		and not bool(boss.get_meta("placeholder", false)) and no_label \
		and with_fallback.is_empty()
	_check("boss resolves to FinalBoss, not a placeholder", ok,
		"id=%s status=%s class=%s hp=%s meta=%s no_label=%s rule=%s" % [
			boss_id, engine_status, global_name, boss.get("health") if boss != null else "?",
			boss.get_meta("boss_id", "") if boss != null else "?", no_label, with_fallback])


func _case_burst_window() -> void:
	var outside_rule := _failures({"outside_damage": 1})
	var inside_rule := _failures({"inside_damage": 0})
	var boss: Node = _stage.get("boss") if _stage != null else null
	var p: Node = _stage.get("player") if _stage != null else null
	var outside_dealt := -1
	var inside_dealt := -1
	var outside_fired := false
	var inside_fired := false
	if boss != null and boss.has_method("reset") and p != null:
		boss.call("reset")
		_prepare_burst(p, boss)
		boss.set("phase", "telegraph")
		var before := int(boss.get("health"))
		outside_fired = bool(p.call("spike_burst"))
		outside_dealt = before - int(boss.get("health"))
		p.set("energy", float(p.get("MAX_ENERGY")))
		p.set("_burst_cooldown", 0.0)
		boss.set("phase", "exposed")
		before = int(boss.get("health"))
		inside_fired = bool(p.call("spike_burst"))
		inside_dealt = before - int(boss.get("health"))
	var ok: bool = _has(outside_rule, "burst-outside") and _has(inside_rule, "burst-inside") \
		and outside_fired and inside_fired and outside_dealt == 0 and inside_dealt == 1
	_check("burst deals 0 outside / exactly 1 inside the weak window", ok,
		"outside_fired=%s outside_dealt=%d inside_fired=%s inside_dealt=%d rules=%s/%s" % [
			outside_fired, outside_dealt, inside_fired, inside_dealt, outside_rule, inside_rule])


func _case_completion_marker() -> void:
	var marker_before: bool = _stage.has_node("CompletionMarker") if _stage != null else true
	var boss: Node = _stage.get("boss") if _stage != null else null
	if boss != null and boss.has_method("take_damage"):
		boss.set("phase", "exposed")
		boss.call("take_damage", WANT_MAX_HEALTH)
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
	var boss_health: int = int(boss.get("health")) if boss != null else -1
	var wind_after: bool = bool(boss.get("second_wind")) if boss != null else true
	var facts := {
		"evolved": bool(p.get("evolved")) if p != null else false,
		"nutrition": float(p.get("nutrition")) if p != null else -1.0,
		"boss_health": boss_health,
		"boss_max_health": WANT_MAX_HEALTH,
	}
	var good := _failures(facts)
	var bad := _failures({
		"evolved": false, "nutrition": -1.0,
		"boss_health": 1, "boss_max_health": WANT_MAX_HEALTH,
	})
	var at_shelter: bool = p != null \
		and is_equal_approx((p as Node2D).global_position.x, CHECKPOINT.x) \
		and is_equal_approx((p as Node2D).global_position.y, CHECKPOINT.y)
	var ok: bool = evolved_before and bool(facts["evolved"]) \
		and is_equal_approx(float(facts["nutrition"]), nutrition_before) \
		and boss_health == WANT_MAX_HEALTH and not wind_after \
		and at_shelter and not _has(good, "retry") and _has(bad, "retry")
	_check("shelter retry keeps progress and resets the boss to 12", ok,
		"evolved=%s nutrition=%.0f boss_hp=%d wind=%s at_shelter=%s failures=%s" % [
			facts["evolved"], float(facts["nutrition"]), boss_health, wind_after,
			at_shelter, good])


func _case_zero_energy_demo_can_fail() -> void:
	if _stage == null:
		_check("zero-energy demo control fails by name", false, "<no stage>")
		return
	var zero: Array = _stage.call("evaluate_demo", {
		"map_id": EXPECTED_ID,
		"evolved": true, "gate_open": true, "completion_count": 0,
		"boss_defeated": false, "boss_health": WANT_MAX_HEALTH,
		"bursts": 0, "nutrition": PlayerController.EVOLVE_COST,
		"min_pos": CHECKPOINT, "max_pos": CHECKPOINT, "room_rect": _room_rect(_json),
	})
	var good: Array = _stage.call("evaluate_demo", {
		"map_id": EXPECTED_ID,
		"evolved": true, "gate_open": true, "completion_count": 1,
		"boss_defeated": true, "boss_health": 0,
		"bursts": WANT_MAX_HEALTH, "nutrition": PlayerController.EVOLVE_COST,
		"min_pos": CHECKPOINT, "max_pos": Vector2(BOSS_X, CHECKPOINT.y),
		"room_rect": _room_rect(_json),
	})
	var ok: bool = _has(zero, "burst-inside") and (good as Array).is_empty()
	_check("zero-energy demo control fails by name", ok,
		"zero=%s good=%s" % [zero, good])


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


func _case_unsupported_ids_rejected() -> void:
	if _stage == null:
		_check("unsupported ids are rejected by name", false, "<no stage>")
		return
	var original_boss: Node = _stage.get("boss")
	var bad_id := _json.duplicate(true)
	bad_id["id"] = "map99"
	var reported_id: Array = _stage.call("load_map_data", bad_id)
	var rule_id := _failures({"map_id": "map99"})
	var bad_future := _json.duplicate(true)
	bad_future["hazards"] = [{"id": "acid_pool", "kind": "hazard_zone"}]
	var reported_future: Array = _stage.call("load_map_data", bad_future)
	var rule_future := _failures({"future_ids": ["hazards"]})
	var bad_boss := _json.duplicate(true)
	var boss_block: Dictionary = (bad_boss.get("boss", {}) as Dictionary).duplicate(true)
	boss_block["id"] = "the_unborn"
	boss_block["fallback_until_implemented"] = null
	bad_boss["boss"] = boss_block
	var reported_boss: Array = _stage.call("load_map_data", bad_boss)
	var rule_boss := _failures({"boss_id": "the_unborn", "has_fallback": false})
	var still_same: bool = original_boss != null and original_boss == _stage.get("boss")
	var real: Array = _stage.call("load_map_data", _json)
	var ok: bool = _has(reported_id, "unsupported") and _has(rule_id, "unsupported") \
		and _has(reported_future, "unsupported") and _has(rule_future, "unsupported") \
		and _has(reported_boss, "unsupported") and _has(rule_boss, "unsupported") \
		and still_same and real.is_empty()
	_check("unsupported ids are rejected by name", ok,
		"map=%s future=%s boss=%s still_same=%s real=%s" % [
			reported_id, reported_future, reported_boss, still_same, real])


func _case_player_full_traversal() -> void:
	if _stage == null:
		_check("player traverses map09 and stays in bounds", false, "<no stage>")
		return
	var p: Node = _stage.get("player")
	if p == null or not (p is Node2D):
		_check("player traverses map09 and stays in bounds", false, "<no player>")
		return
	# Fresh rebuild so earlier cases (evolution, boss defeat) cannot help here.
	_stage.call("load_map_data", _json)
	p = _stage.get("player")
	p.set("demo_active", true)
	p.set("state", 0) # SWIM — isolate geometry from any other state
	p.set("dead", false)
	p.set("health", 99)
	p.set("velocity", Vector2.ZERO)
	(p as Node2D).global_position = CHECKPOINT
	p.set("demo_dir", Vector2.RIGHT)
	var reached_zone := false
	var min_x := INF
	var max_x := -INF
	for i in 600:
		await physics_frame
		var pos: Vector2 = (p as Node2D).global_position
		min_x = minf(min_x, pos.x)
		max_x = maxf(max_x, pos.x)
		if pos.x >= ZONE_X - 20.0:
			reached_zone = true
			break
	p.set("demo_dir", Vector2.ZERO)
	await _frames(2)
	# Bounds proof: a forced excursion must be clamped back into the room.
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
	var gate_held: bool = max_x < GATE_LEFT_X
	var ok: bool = reached_zone and gate_held and tracked and excursion and clamped_back \
		and _has(raw_fail, "bounds") and clamped_fail.is_empty() \
		and _has(violating, "bounds")
	_check("player traverses map09 and stays in bounds", ok,
		"zone=%s x=%.0f..%.0f gate_held=%s raw=%s..%s final=%s excursion=%s clamped=%s" % [
			reached_zone, min_x, max_x, gate_held, raw_min, raw_max, final_pos,
			excursion, clamped_back])


# ------------------------------------------------------------------- entry

func _init() -> void:
	await _frames(2)
	_json = _read_json(MAP_RES)
	_stage = _make_stage()
	await _frames(3)
	await _case_final_boss_has_twelve_health()
	await _case_phase_one_timings()
	await _case_second_wind_at_half_health()
	await _case_damage_only_while_exposed()
	await _case_defeat_emitted_once()
	await _case_runtime_json_loads()
	await _case_slabs_match_rects()
	await _case_player_at_checkpoint()
	await _case_motes_and_zone()
	await _case_convergence_membrane_closed_then_open()
	await _case_planned_grant_via_two_tier()
	await _case_boss_is_final_boss_class()
	await _case_burst_window()
	await _case_completion_marker()
	await _case_retry_preserves_progress()
	await _case_zero_energy_demo_can_fail()
	await _case_runtime_copy_drift()
	await _case_unsupported_ids_rejected()
	await _case_player_full_traversal()
	if _stage != null and is_instance_valid(_stage):
		_stage.queue_free()
	await _frames(2)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] map09_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
