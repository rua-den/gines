extends SceneTree
## Headless rule check for the parameterized map08 stage ("The Passage").
##
## Eighteen named cases. map08 is the FINAL, explicitly labeled placeholder
## finale:
##   - `integrated_form` and `combo_mastery` are PLANNED grants, accepted only
##     because the scene acknowledges them, the JSON says engine_status=planned
##     and a non-empty fallback exists. They are NEVER claimed as implemented;
##     they are reported as `placeholder_grants`.
##   - the planned boss `the_last_overgrowth` has NO built_from, so its documented
##     Rot Bloom fallback resolves to a clearly LABELED BloomBoss placeholder
##     (Proposed, design-only — never an approved enemy or art).
##   - the `final_membrane` obstacle is a PLANNED `gate`, built by the existing
##     builder as an INERT static slab (hide-on-defeat pattern). It is a
##     placeholder, NOT an implemented birth gate: no birth cinematic and no
##     combo input exist, and complete_text says so honestly.
##   - the signature geometry is a constriction (upper slab y 60..580, lower
##     slab y 720..980) leaving a 140 px low route at y 580..720. The traversal
##     case swims through that gap with the existing movement controller and
##     stays in bounds — no double-jump, glide or combo is invented.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/map08_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 18
const MAP_RES := "res://resources/maps/map08.json"
const STAGE_SCENE := "res://scenes/map08.tscn"
const EXPECTED_ID := "map08"
const EXPECTED_OBSTACLES := 5
const EXPECTED_MOTES := 3
const CHECKPOINT := Vector2(300.0, 520.0)
const BOSS_X := 1840.0
const GATE_LEFT_X := 1700.0
const GATE_END_X := 1740.0
const LOW_ROUTE_Y := 650.0
const EPS := 0.001

# Mirrors the two capability sets declared in map_stage.gd. Kept in the test so
# a drift in either list is caught by the assertions below.
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
	# Test-only: the canonical map lives outside res://. The stage never uses
	# this path (runtime copies are read from res://resources/maps/).
	return ProjectSettings.globalize_path("res://") + "../docs/maps/map08.json"


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


func _case_gate_placeholder_closed_then_open() -> void:
	if _stage == null:
		_check("final membrane is a placeholder gate; closed then open", false, "<no stage>")
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
	# The gate is a PLANNED membrane built as an inert static slab, not a birth
	# gate. No birth cinematic / combo input node may exist in the stage.
	var placeholder_ok: bool = json_has_gate and gate_id == "final_membrane" \
		and gate_status == "planned" and not gate_fallback.is_empty() \
		and gate is StaticBody2D \
		and _stage.get_node_or_null("BirthCinematic") == null \
		and _stage.get_node_or_null("Birth") == null
	var complete_text := str(_stage.get("complete_text"))
	var honest_text: bool = complete_text.begins_with("MAP08 COMPLETE") \
		and complete_text.find("placeholder") != -1 \
		and complete_text.find("birth cinematic is Open") != -1 \
		and complete_text.find("birth sequence implemented") == -1 \
		and complete_text.find("birth implemented") == -1
	var closed_before: bool = gate != null and int(gate.collision_layer) == 2 \
		and gate.visible and not bool(_stage.call("gate_open"))
	# Physically blocked before evolution: drive into the membrane's left face.
	var blocked := false
	if p != null and gate != null:
		p.set("demo_active", true)
		p.set("velocity", Vector2.ZERO)
		(p as Node2D).global_position = Vector2(GATE_LEFT_X - 120.0, LOW_ROUTE_Y)
		p.set("demo_dir", Vector2.RIGHT)
		for i in 120:
			await physics_frame
		blocked = (p as Node2D).global_position.x < GATE_LEFT_X - 40.0
	p.set("demo_dir", Vector2.ZERO)
	# Evolve with the implemented fallback abilities; the membrane opens.
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
	_check("final membrane is a placeholder gate; closed then open", ok,
		"id=%s status=%s placeholder=%s text_ok=%s closed=%s blocked=%s open=%s passed=%s rules=%s/%s/%s" % [
			gate_id, gate_status, placeholder_ok, honest_text, closed_before, blocked,
			open_after, passed, bad, good, early])


func _case_planned_grants_are_placeholders() -> void:
	var placeholder: Variant = _stage.get("placeholder_grants") if _stage != null else null
	var upgrade: Dictionary = _json.get("upgrade", {})
	var json_grants: Array = upgrade.get("grants", [])
	var json_status := str(upgrade.get("engine_status", ""))
	var json_fallback := str(upgrade.get("fallback_until_implemented", ""))
	var expected_planned: Array[String] = []
	for g in json_grants:
		if PLANNED.has(str(g)):
			expected_planned.append(str(g))
	# Exact, order-preserving equality with the JSON's planned grants.
	var exact: bool = placeholder is Array \
		and (placeholder as Array).size() == expected_planned.size()
	if exact:
		for i in expected_planned.size():
			if str((placeholder as Array)[i]) != expected_planned[i]:
				exact = false
				break
	# Must be disjoint from the implemented whitelist (never claim implemented).
	var disjoint := true
	if placeholder is Array:
		for g in (placeholder as Array):
			if SUPPORTED.has(str(g)):
				disjoint = false
	# Honest HUD marker in the CanvasLayer: both planned ids must appear.
	var marker_text := ""
	if _stage != null:
		for child in _stage.get_children():
			if child is CanvasLayer:
				for c in child.get_children():
					if c is Label and str((c as Label).text).begins_with("PLANNED FALLBACK:"):
						marker_text = str((c as Label).text)
	var honest := not marker_text.is_empty()
	for id in expected_planned:
		honest = honest and marker_text.find(id) != -1
	var result_pass := str(_stage.call("result_line", true)) if _stage != null else ""
	var result_honest := result_pass == "MAP08 RESULT: PASS (placeholder)"
	var ok: bool = json_status == "planned" and not json_fallback.is_empty() \
		and expected_planned.size() == 2 and exact and disjoint and honest \
		and result_honest
	_check("planned grants load as placeholders with honest marker", ok,
		"placeholder=%s expected=%s disjoint=%s marker='%s' result='%s' status=%s fallback='%s'" % [
			placeholder, expected_planned, disjoint, marker_text, result_pass,
			json_status, json_fallback])


func _case_boss_is_labeled_placeholder() -> void:
	var boss: Node = _stage.get("boss") if _stage != null else null
	var boss_id := str((_json.get("boss", {}) as Dictionary).get("id", ""))
	var with_fallback := _failures({"boss_id": boss_id, "has_fallback": true})
	var without_fallback := _failures({"boss_id": boss_id, "has_fallback": false})
	var label_node: Node = boss.get_node_or_null("PlaceholderLabel") if boss != null else null
	var label_text := str((label_node as Label).text) if label_node is Label else ""
	var honest: bool = label_text.find("PLACEHOLDER") != -1 \
		and label_text.find(boss_id) != -1 \
		and label_text.find("not approved") != -1
	var ok: bool = boss_id == "the_last_overgrowth" and boss is BloomBoss \
		and int(boss.get("health")) == BloomBoss.MAX_HEALTH \
		and boss.name == "BossPlaceholder" \
		and bool(boss.get_meta("placeholder", false)) \
		and str(boss.get_meta("boss_id", "")) == boss_id \
		and honest and with_fallback.is_empty() \
		and _has(without_fallback, "unsupported")
	_check("planned boss is a labeled BloomBoss placeholder", ok,
		"boss_id=%s boss=%s name=%s placeholder=%s meta=%s health=%s label=%s with_fb=%s without_fb=%s" % [
			boss_id,
			boss.get_script().get_global_name() if boss != null and boss.get_script() != null else "<none>",
			boss.name if boss != null else "<none>",
			boss.get_meta("placeholder", false) if boss != null else "?",
			boss.get_meta("boss_id", "") if boss != null else "?",
			boss.get("health") if boss != null else "?",
			label_text, with_fallback, without_fallback])


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
		and is_equal_approx((p as Node2D).global_position.x, CHECKPOINT.x) \
		and is_equal_approx((p as Node2D).global_position.y, CHECKPOINT.y)
	var ok: bool = evolved_before and bool(facts["evolved"]) \
		and is_equal_approx(float(facts["nutrition"]), nutrition_before) \
		and int(facts["boss_health"]) == BloomBoss.MAX_HEALTH \
		and at_shelter and not _has(good, "retry") and _has(bad, "retry")
	_check("shelter retry keeps progress and resets the boss", ok,
		"evolved=%s nutrition=%.0f boss_hp=%d at_shelter=%s failures=%s" % [
			facts["evolved"], float(facts["nutrition"]), int(facts["boss_health"]),
			at_shelter, good])


func _case_player_traverses_constriction_low_route() -> void:
	if _stage == null:
		_check("player swims the low route and stays in bounds", false, "<no stage>")
		return
	var p: Node = _stage.get("player")
	if p == null or not (p is Node2D):
		_check("player swims the low route and stays in bounds", false, "<no player>")
		return
	p.set("demo_active", true)
	p.set("state", 0) # SWIM — isolate geometry from any inherited CRAWL/GRIP state
	p.set("dead", false)
	p.set("health", 99) # isolate geometry from the placeholder boss's attack
	p.set("velocity", Vector2.ZERO)
	# Enter the passage aligned with the 140 px low route (y 580..720); with a
	# 55 px radius the centre must stay in y 635..665 to fit between the slabs.
	(p as Node2D).global_position = Vector2(300.0, LOW_ROUTE_Y)
	p.set("demo_dir", Vector2.RIGHT)
	var passed_gap := false
	var min_y := INF
	var max_y := -INF
	for i in 600:
		await physics_frame
		var pos: Vector2 = (p as Node2D).global_position
		min_y = minf(min_y, pos.y)
		max_y = maxf(max_y, pos.y)
		if pos.x > 850.0: # upper/lower constrictions end at x=790 (+55 radius)
			passed_gap = true
			break
	p.set("demo_dir", Vector2.ZERO)
	await _frames(2)
	var in_route: bool = min_y >= 580.0 and max_y <= 720.0
	# Bounds proof: force a raw excursion, then verify the clamp and tracking.
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
	var ok: bool = passed_gap and in_route and tracked and excursion and clamped_back \
		and _has(raw_fail, "bounds") and clamped_fail.is_empty() \
		and _has(violating, "bounds")
	_check("player swims the low route and stays in bounds", ok,
		"gap=%s y=%.0f..%.0f raw=%s..%s final=%s excursion=%s clamped=%s" % [
			passed_gap, min_y, max_y, raw_min, raw_max, final_pos, excursion, clamped_back])


func _case_planned_grant_negative_controls() -> void:
	if _stage == null:
		_check("planned grant negative controls fail by name", false, "<no stage>")
		return
	var original_ack: Array = (_stage.get("acknowledged_planned_grants") as Array).duplicate()
	# (a) a planned grant marked implemented must be rejected as a placeholder.
	var a := _json.duplicate(true)
	(a["upgrade"] as Dictionary)["engine_status"] = "implemented"
	var ra: Array = _stage.call("load_map_data", a)
	# (b) an empty fallback must be rejected as a placeholder.
	var b := _json.duplicate(true)
	(b["upgrade"] as Dictionary)["fallback_until_implemented"] = ""
	var rb: Array = _stage.call("load_map_data", b)
	# (c) an id in neither set must be named unsupported.
	var c := _json.duplicate(true)
	var cg: Array = ((c["upgrade"] as Dictionary)["grants"] as Array).duplicate()
	cg.append("fission_dash")
	(c["upgrade"] as Dictionary)["grants"] = cg
	var rc: Array = _stage.call("load_map_data", c)
	# (d) a scene that omits the acknowledgment must be rejected as a placeholder.
	var empty_ack: Array[String] = []
	_stage.set("acknowledged_planned_grants", empty_ack)
	var rd: Array = _stage.call("load_map_data", _json)
	_stage.set("acknowledged_planned_grants", original_ack)
	var restored: Array = _stage.call("load_map_data", _json)
	var ok: bool = _has(ra, "placeholder") and _has(rb, "placeholder") \
		and _has(rc, "unsupported") and _has(rd, "placeholder") \
		and restored.is_empty()
	_check("planned grant negative controls fail by name", ok,
		"implemented=%s empty_fallback=%s neither_set=%s no_ack=%s restored=%s" % [
			ra, rb, rc, rd, restored])


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
	var generic_ok: bool = bool(_stage.call("is_demo_arg", "--map-demo=map08"))
	var legacy_ok: bool = bool(_stage.call("is_demo_arg", "--map08-demo"))
	var other_generic: bool = bool(_stage.call("is_demo_arg", "--map-demo=map02"))
	var other_legacy: bool = bool(_stage.call("is_demo_arg", "--map02-demo"))
	var ok: bool = flag == "--map-demo=map08" and prefix == "[MAP08]" \
		and pass_line == "MAP08 RESULT: PASS (placeholder)" \
		and fail_line == "MAP08 RESULT: FAIL" \
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
	bad["fission_dash"] = {"id": "stage8", "status": "Open"}
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
	await _case_gate_placeholder_closed_then_open()
	await _case_planned_grants_are_placeholders()
	await _case_boss_is_labeled_placeholder()
	await _case_burst_window()
	await _case_completion_marker()
	await _case_retry_preserves_progress()
	await _case_player_traverses_constriction_low_route()
	await _case_planned_grant_negative_controls()
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
	print("[T] map08_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
