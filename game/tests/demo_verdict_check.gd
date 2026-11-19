extends SceneTree
## Headless regression check: the Milestone 1 demo must be able to FAIL.
##
## Contract: movement_test.gd owns a single verdict function that turns the
## demo's raw observations into a list of failed acceptance criteria. An empty
## list means PASS. If this function cannot report a failure, a broken demo
## run would still exit 0 and be recorded as a pass.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/demo_verdict_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 5

var _failures := 0
var _cases_run := 0

const GOOD_HISTORY: Array[String] = ["SWIM->CRAWL", "CRAWL->SWIM", "SWIM->GRIP", "GRIP->SWIM"]
const GOOD_MIN := Vector2(300.0, 368.0)
const GOOD_MAX := Vector2(1744.0, 965.0)


func _case(label: String, history: Array[String], min_pos: Vector2, max_pos: Vector2, camera_dx: float, shots: int, expect_ok: bool) -> void:
	_cases_run += 1
	var scene: Node = load("res://scenes/movement_test.tscn").instantiate()
	# A GDScript runtime error aborts the call but does not fail the run, so
	# a missing/broken verdict function must be reported explicitly here.
	if not scene.has_method("evaluate_demo"):
		_failures += 1
		scene.free()
		print("[T] FAIL %-46s movement_test.gd has no evaluate_demo()" % label)
		return
	var failures: Array = scene.evaluate_demo(history, min_pos, max_pos, camera_dx, shots)
	scene.free()
	var ok: bool = (failures.is_empty() == expect_ok)
	if not ok:
		_failures += 1
	print("[T] %s %-46s failures=%s expect_ok=%s" % [
		"PASS" if ok else "FAIL", label, failures, expect_ok])


func _init() -> void:
	await process_frame
	_case("all criteria met is a pass", GOOD_HISTORY, GOOD_MIN, GOOD_MAX, 1444.0, 4, true)
	_case("missing 4th screenshot fails", GOOD_HISTORY, GOOD_MIN, GOOD_MAX, 1444.0, 3, false)
	_case("camera not following fails", GOOD_HISTORY, GOOD_MIN, GOOD_MAX, 10.0, 4, false)
	_case("leaving the room fails", GOOD_HISTORY, Vector2(10.0, 368.0), GOOD_MAX, 1444.0, 4, false)
	_case("missing GRIP state fails", ["SWIM->CRAWL", "CRAWL->SWIM"], GOOD_MIN, GOOD_MAX, 1444.0, 4, false)
	if _cases_run != EXPECTED_CASES:
		_failures += 1
		print("[T] FAIL only %d of %d cases ran" % [_cases_run, EXPECTED_CASES])
	print("[T] demo_verdict_check: ", "ALL PASS" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)
