extends SceneTree
## Headless regression check: the M2 demo verdict must be able to fail.
##
## Contract: prototype.gd owns evaluate_demo(); an empty failure list means PASS.
## If this function cannot report a failure, a broken demo run exits 0 and gets
## recorded as evidence — the exact defect fixed in the M1 close-out.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/m2_verdict_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 7
const GOOD_MIN := Vector2(300.0, 368.0)
const GOOD_MAX := Vector2(1744.0, 965.0)

var _passed := 0
var _failed := 0


func _case(label: String, absorbed: int, hits: int, retries: int, shots: int,
		min_pos: Vector2, max_pos: Vector2, revived: bool, expect_ok: bool) -> void:
	var scene: Node = load("res://scenes/prototype.tscn").instantiate()
	if not scene.has_method("evaluate_demo"):
		scene.free()
		_failed += 1
		print("[T] FAIL %-42s prototype.gd has no evaluate_demo()" % label)
		return
	var failures: Array = scene.evaluate_demo(absorbed, hits, retries, shots, min_pos, max_pos, revived)
	scene.free()
	var ok: bool = failures.is_empty() == expect_ok
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-42s expect_ok=%s failures=%s" % ["PASS" if ok else "FAIL", label, expect_ok, failures])


func _init() -> void:
	await process_frame
	_case("all criteria met is a pass", 1, 1, 1, 3, GOOD_MIN, GOOD_MAX, true, true)
	_case("no absorption fails", 0, 1, 1, 3, GOOD_MIN, GOOD_MAX, true, false)
	_case("no damage fails", 1, 0, 1, 3, GOOD_MIN, GOOD_MAX, true, false)
	_case("no retry fails", 1, 1, 0, 3, GOOD_MIN, GOOD_MAX, true, false)
	_case("revived=false fails", 1, 1, 1, 3, GOOD_MIN, GOOD_MAX, false, false)
	_case("leaving the room fails", 1, 1, 3, 3, Vector2(10.0, 368.0), GOOD_MAX, true, false)
	_case("missing screenshot fails", 1, 1, 3, 2, GOOD_MIN, GOOD_MAX, true, false)
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] m2_verdict_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
