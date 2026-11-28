extends SceneTree
## Headless regression check: the M5 demo verdict must be able to fail.
##
## Contract: boss_fight.gd owns evaluate_m5_demo(); an empty failure list means
## PASS. A verdict that always passes would record a broken run as evidence, so
## every criterion is exercised with one broken input. Named criteria are checked
## by substring: "some failure happened" is not enough for a named shot or rule.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/m5_verdict_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 5
const GOOD_SHOTS := ["approach", "telegraph", "weak-window", "victory"]

var _passed := 0
var _failed := 0


func _case(label: String, evolved: bool, defeated: bool, shots: Array,
		nutrition: float, bursts: int, expect_ok: bool,
		needs: Array[String] = []) -> void:
	var scene: Node = load("res://scenes/boss_test.tscn").instantiate()
	if not scene.has_method("evaluate_m5_demo"):
		scene.free()
		_failed += 1
		print("[T] FAIL %-42s boss_fight.gd has no evaluate_m5_demo()" % label)
		return
	var failures: Array = scene.evaluate_m5_demo(evolved, defeated, shots, nutrition, bursts)
	scene.free()
	var ok: bool = failures.is_empty() == expect_ok
	# Every named criterion must appear in the failure list on its own line;
	# one generic failure cannot stand in for three broken rules.
	for needle in needs:
		var found := false
		for failure in failures:
			if str(failure).contains(needle):
				found = true
				break
		if not found:
			ok = false
			print("[T] FAIL %-42s missing failure named \"%s\"" % [label, needle])
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-42s expect_ok=%s failures=%s" % [
		"PASS" if ok else "FAIL", label, expect_ok, failures])


func _case_demo_watchdog_tracks_map_stage() -> void:
	# Keep M5's failure watchdog at least as generous as the full map demos.
	# Read both live script constants so a future cadence change cannot drift.
	var scene: Node = load("res://scenes/boss_test.tscn").instantiate()
	var boss_script := scene.get_script() as GDScript
	var boss_constants: Dictionary = boss_script.get_script_constant_map() if boss_script != null else {}
	var boss_timeout := float(boss_constants.get("DEMO_TIMEOUT", 0.0))
	var map_script := load("res://scripts/map_stage.gd") as GDScript
	var map_constants: Dictionary = map_script.get_script_constant_map() if map_script != null else {}
	var map_timeout := float(map_constants.get("DEMO_TIMEOUT", 0.0))
	scene.free()
	var ok: bool = map_timeout > 0.0 and boss_timeout >= map_timeout
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s M5 demo watchdog tracks map-stage watchdog  M5=%.0f map=%.0f" % [
		"PASS" if ok else "FAIL", boss_timeout, map_timeout])


func _init() -> void:
	await process_frame
	_case("all criteria met is a pass", true, true, GOOD_SHOTS, 0.0, 6, true)
	_case("victory missing, weak-window duplicated", true, true,
		["approach", "telegraph", "weak-window", "weak-window"], 0.0, 6, false, ["victory"])
	# Grouped case: an unevolved run, an undefeated boss and zero bursts must
	# each produce their own named failure line, not one generic message.
	_case("unevolved, undefeated, zero bursts", false, false,
		GOOD_SHOTS, 0.0, 0, false, ["evolution", "boss", "burst"])
	_case("negative nutrition is an economy failure", true, true,
		GOOD_SHOTS, -1.0, 6, false, ["nutrition"])
	_case_demo_watchdog_tracks_map_stage()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] m5_verdict_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
