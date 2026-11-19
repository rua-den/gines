extends SceneTree
## Headless regression check: the M3 demo verdict must be able to fail.
##
## Contract: prototype.gd owns evaluate_m3_demo(); an empty failure list means
## PASS. A verdict that always passes would record a broken run as evidence, so
## every criterion is exercised with one broken input.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/m3_verdict_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 8
const GOOD_SHOTS := ["requirement", "evolve", "burst", "kill"]
const GOOD_MIN := Vector2(300.0, 250.0)
const GOOD_MAX := Vector2(1700.0, 900.0)


var _passed := 0
var _failed := 0


func _case(label: String, evolved: bool, killed: bool, shots: Array, nutrition: float,
		min_pos: Vector2, max_pos: Vector2, expect_ok: bool) -> void:
	var scene: Node = load("res://scenes/prototype.tscn").instantiate()
	if not scene.has_method("evaluate_m3_demo"):
		scene.free()
		_failed += 1
		print("[T] FAIL %-42s prototype.gd has no evaluate_m3_demo()" % label)
		return
	var failures: Array = scene.evaluate_m3_demo(evolved, killed, shots, nutrition, min_pos, max_pos)
	scene.free()
	var ok: bool = failures.is_empty() == expect_ok
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-42s expect_ok=%s failures=%s" % ["PASS" if ok else "FAIL", label, expect_ok, failures])


func _init() -> void:
	await process_frame
	_case("all criteria met is a pass", true, true, GOOD_SHOTS, 15.0, GOOD_MIN, GOOD_MAX, true)
	_case("no evolution fails", false, true, GOOD_SHOTS, 15.0, GOOD_MIN, GOOD_MAX, false)
	_case("no kill fails", true, false, GOOD_SHOTS, 15.0, GOOD_MIN, GOOD_MAX, false)
	_case("unpaid evolution fails", true, true, GOOD_SHOTS, 0.0, GOOD_MIN, GOOD_MAX, false)
	_case("missing burst shot fails", true, true, ["requirement", "evolve", "kill"], 15.0, GOOD_MIN, GOOD_MAX, false)
	_case("duplicate shot cannot stand in", true, true,
		["requirement", "evolve", "burst", "burst"], 15.0, GOOD_MIN, GOOD_MAX, false)
	_case("leaving the room fails", true, true, GOOD_SHOTS, 15.0, Vector2(10.0, 250.0), GOOD_MAX, false)
	_case("empty capture list fails", true, true, [], 15.0, GOOD_MIN, GOOD_MAX, false)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] m3_verdict_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
