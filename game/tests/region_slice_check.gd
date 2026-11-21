extends SceneTree
## Headless rule check for the additive region slice (prototype -> boss arena).
##
## The slice exposes a pure evaluate_slice_run(facts) so every progression rule
## is pinned by a named case without a window. Cases 1/4/5/8 also read the real
## instanced scene so a broken integration cannot pass on rules alone.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/region_slice_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 9

var _passed := 0
var _failed := 0
var _slice: RegionSlice = null


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


func _make_slice() -> RegionSlice:
	var s: RegionSlice = load("res://scenes/region_slice.tscn").instantiate()
	get_root().add_child(s)
	return s


func _failures(s: RegionSlice, facts: Dictionary) -> Array[String]:
	return s.evaluate_slice_run(facts)


func _has_rule(failures: Array[String], rule: String) -> bool:
	for f in failures:
		if f.begins_with(rule + ":"):
			return true
	return false


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
	if root is Camera2D and root.is_current():
		count += 1
	for child in root.get_children():
		count += _count_current_cameras(child)
	return count


# ------------------------------------------------------------------- cases

func _case_fresh_run() -> void:
	var prelude: Node = _slice.get("prelude")
	var p: Node = prelude.get("player")
	await _frames(2)
	var evolved: bool = bool(p.get("evolved"))
	var nutrition: float = float(p.get("nutrition"))
	var cost: float = float(p.get("EVOLVE_COST"))
	var failures := _failures(_slice, {
		"evolved": evolved,
		"nutrition": nutrition,
		"evolve_cost": cost,
	})
	var ok: bool = not evolved and nutrition < cost and not _has_rule(failures, "fresh-start")
	_check("fresh run starts unevolved and underfed", ok,
		"evolved=%s nutrition=%.0f cost=%.0f failures=%s" % [evolved, nutrition, cost, failures])


func _case_unevolved_boundary() -> void:
	var failures := _failures(_slice, {"at_boundary": true, "evolved": false})
	var ok: bool = _has_rule(failures, "transition")
	_check("unevolved at the boundary does not transition", ok, "failures=%s" % [failures])


func _case_evolved_boundary() -> void:
	var failures := _failures(_slice, {"at_boundary": true, "evolved": true})
	var ok: bool = not _has_rule(failures, "transition")
	_check("evolved at the boundary transitions", ok, "failures=%s" % [failures])


func _drive_transition() -> void:
	var prelude: Node = _slice.get("prelude")
	var p: Node = prelude.get("player")
	p.set("evolved", true)
	p.set("nutrition", float(p.get("EVOLVE_COST")))
	p.global_position = Vector2(1880.0, 500.0)
	# Poll the controller synchronously: headless physics can shove the body back
	# off the boundary before the next frame's _process samples it.
	_slice.call("_process", 0.016)
	await _frames(2)
	print("[T] slice state after boundary: ", _slice.get("state"))


func _case_single_actor() -> void:
	var arena: Node = _slice.get("arena")
	var players := _count_class(get_root(), "PlayerController")
	var cameras := _count_current_cameras(get_root())
	var failures := _failures(_slice, {
		"player_count": players,
		"current_camera_count": cameras,
	})
	var ok: bool = _slice.get("state") == "ARENA" \
		and _slice.get("prelude") == null \
		and arena != null and is_instance_valid(arena) \
		and players == 1 and cameras == 1 \
		and not _has_rule(failures, "actors")
	_check("exactly one player and camera after transition", ok,
		"state=%s players=%d cameras=%d failures=%s" % [
			_slice.get("state"), players, cameras, failures])


func _case_gate_handoff() -> void:
	var arena: Node = _slice.get("arena")
	var gate_open: bool = arena != null and bool(arena.call("gate_open"))
	var boss: Node = arena.get("boss") if arena != null else null
	var boss_has_player: bool = boss != null and boss.get("player") != null
	var failures := _failures(_slice, {
		"gate_open": gate_open,
		"boss_has_player": boss_has_player,
	})
	var ok: bool = gate_open and boss_has_player and not _has_rule(failures, "gate")
	_check("arena loads with an open gate and a boss player", ok,
		"gate_open=%s boss_has_player=%s failures=%s" % [gate_open, boss_has_player, failures])


func _case_burst_outside() -> void:
	var failures := _failures(_slice, {"outside_damage": 0})
	var ok: bool = not _has_rule(failures, "burst-outside")
	_check("burst outside the weak window deals no boss damage", ok, "failures=%s" % [failures])


func _case_burst_inside() -> void:
	var failures := _failures(_slice, {"inside_damage": 1})
	var ok: bool = not _has_rule(failures, "burst-inside")
	_check("burst inside the weak window deals exactly one", ok, "failures=%s" % [failures])


func _case_completion() -> void:
	var arena: Node = _slice.get("arena")
	var marker_before: bool = _slice.has_node("RegionCompleteLabel")
	if arena != null:
		arena.set("boss_defeated", true)
		await _frames(3)
	var reported: bool = bool(_slice.get("completion_reported"))
	var marker_count := 0
	for child in _slice.get_children():
		if child.name == "RegionCompleteLabel" and child is Label:
			marker_count += 1
	var failures := _failures(_slice, {
		"marker_before_defeat": marker_before,
		"completion_count": marker_count,
	})
	var ok: bool = not marker_before and reported and marker_count == 1 \
		and _slice.get("state") == "COMPLETE" \
		and not _has_rule(failures, "completion")
	_check("completion marker waits for defeat and fires once", ok,
		"before=%s reported=%s markers=%d state=%s failures=%s" % [
			marker_before, reported, marker_count, _slice.get("state"), failures])


func _case_retry() -> void:
	var arena: Node = _slice.get("arena")
	if arena != null:
		arena.call("retry")
	var boss: Node = arena.get("boss") if arena != null else null
	var p: Node = arena.get("player") if arena != null else null
	var facts := {
		"evolved": bool(p.get("evolved")) if p != null else false,
		"nutrition": float(p.get("nutrition")) if p != null else 0.0,
		"boss_health": int(boss.get("health")) if boss != null else -1,
		"boss_max_health": BloomBoss.MAX_HEALTH,
	}
	var failures := _failures(_slice, facts)
	var ok: bool = bool(facts["evolved"]) and float(facts["nutrition"]) >= 0.0 \
		and int(facts["boss_health"]) == BloomBoss.MAX_HEALTH \
		and not _has_rule(failures, "retry")
	_check("retry preserves progress and resets the boss", ok,
		"evolved=%s nutrition=%.0f boss_health=%d failures=%s" % [
			facts["evolved"], facts["nutrition"], facts["boss_health"], failures])


# ------------------------------------------------------------------- entry

func _init() -> void:
	SaveState.clear(SaveState.DEFAULT_PATH)
	_slice = _make_slice()
	await _frames(3)
	await _case_fresh_run()
	await _drive_transition()
	await _case_unevolved_boundary()
	await _case_evolved_boundary()
	await _case_single_actor()
	await _case_gate_handoff()
	await _case_burst_outside()
	await _case_burst_inside()
	await _case_completion()
	await _case_retry()
	SaveState.clear(SaveState.DEFAULT_PATH)
	if _slice != null and is_instance_valid(_slice):
		_slice.queue_free()
	await _frames(2)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] region_slice_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
