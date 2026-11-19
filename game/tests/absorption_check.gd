extends SceneTree
## Headless regression check: absorption channel contract (Milestone 2).
##
## Contract (see player.gd / absorbable.gd):
##   Holding `interact` within ABSORB_RANGE of an unconsumed absorbable channels for
##   ABSORB_CHANNEL seconds, then consumes the mote once and adds its nutrition.
##   Releasing, leaving range, or taking damage resets the channel without consuming.
##   A consumed mote can never be absorbed twice. Feeding lowers the swim speed cap.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/absorption_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 6
const HOLD_FRAMES := 70 # > ABSORB_CHANNEL (0.75 s at 60 Hz)

var _passed := 0
var _failed := 0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _setup() -> Dictionary:
	var root := Node2D.new()
	get_root().add_child(root)
	var p: PlayerController = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(500, 500)
	root.add_child(p)
	p.demo_active = true
	p.demo_dir = Vector2.ZERO
	var mote: Absorbable = Absorbable.new()
	mote.position = Vector2(540, 500) # 40 px away, inside range
	mote.drift = false
	root.add_child(mote)
	return {"root": root, "player": p, "mote": mote}


func _teardown(ctx: Dictionary) -> void:
	ctx["root"].queue_free()
	await _frames(2)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


func _case_completes() -> void:
	var ctx := _setup()
	var p: PlayerController = ctx["player"]
	var mote: Absorbable = ctx["mote"]
	var signal_hits := [0]
	p.nutrition_gained.connect(func(_a: float) -> void: signal_hits[0] += 1)
	p.demo_interact_held = true
	await _frames(HOLD_FRAMES)
	var ok: bool = mote.consumed and is_equal_approx(p.nutrition, mote.nutrition_value) and signal_hits[0] == 1
	_check("holding interact consumes the mote once", ok,
		"consumed=%s nutrition=%.1f signals=%d" % [mote.consumed, p.nutrition, signal_hits[0]])
	await _teardown(ctx)


func _case_release_resets() -> void:
	var ctx := _setup()
	var p: PlayerController = ctx["player"]
	var mote: Absorbable = ctx["mote"]
	p.demo_interact_held = true
	await _frames(20)
	var mid: float = mote.progress
	p.demo_interact_held = false
	await _frames(5)
	var ok := mid > 0.0 and not mote.consumed and is_zero_approx(mote.progress) and is_zero_approx(p.nutrition)
	_check("releasing interact resets progress", ok,
		"progress@release=%.2f after=%.2f consumed=%s" % [mid, mote.progress, mote.consumed])
	await _teardown(ctx)


func _case_leaving_range_resets() -> void:
	var ctx := _setup()
	var p: PlayerController = ctx["player"]
	var mote: Absorbable = ctx["mote"]
	p.demo_interact_held = true
	await _frames(20)
	var mid: float = mote.progress
	mote.position = Vector2(1500, 500) # far outside ABSORB_RANGE
	await _frames(10)
	var ok := mid > 0.0 and not mote.consumed and is_zero_approx(mote.progress)
	_check("leaving range resets progress", ok,
		"progress@leave=%.2f after=%.2f consumed=%s" % [mid, mote.progress, mote.consumed])
	await _teardown(ctx)


func _case_no_double_absorb() -> void:
	var ctx := _setup()
	var p: PlayerController = ctx["player"]
	var mote: Absorbable = ctx["mote"]
	p.demo_interact_held = true
	await _frames(HOLD_FRAMES)
	var first := p.nutrition
	await _frames(30)
	var ok := is_equal_approx(p.nutrition, first) and mote.consumed
	_check("a consumed mote cannot be absorbed twice", ok,
		"nutrition after first=%.1f then=%.1f" % [first, p.nutrition])
	await _teardown(ctx)


func _case_damage_cancels() -> void:
	var ctx := _setup()
	var p: PlayerController = ctx["player"]
	var mote: Absorbable = ctx["mote"]
	p.demo_interact_held = true
	await _frames(20)
	var mid: float = mote.progress
	p.take_damage(1, p.global_position + Vector2(60, 0))
	# The cancel must be immediate: absorb_target cleared and the mote's
	# progress zeroed in the damage call itself, not on a later frame.
	var cancelled: bool = p.absorb_target == null and is_zero_approx(mote.progress)
	p.demo_interact_held = false
	await _frames(2)
	var ok := mid > 0.0 and cancelled and not mote.consumed and is_zero_approx(mote.progress) and p.health == p.MAX_HEALTH - 1
	_check("damage cancels the channel", ok,
		"progress@hit=%.2f after=%.2f cancelled=%s consumed=%s health=%d" % [mid, mote.progress, cancelled, mote.consumed, p.health])
	await _teardown(ctx)


func _case_feeding_slows() -> void:
	var ctx := _setup()
	var p: PlayerController = ctx["player"]
	var mote: Absorbable = ctx["mote"]
	p.demo_dir = Vector2.RIGHT
	p.demo_interact_held = true
	await _frames(25)
	var feeding_cap := p.speed_cap()
	p.demo_interact_held = false
	await _frames(5)
	var free_cap := p.speed_cap()
	var ok := feeding_cap < free_cap and is_equal_approx(feeding_cap, p.FEED_SPEED_CAP)
	_check("feeding lowers the speed cap", ok,
		"cap feeding=%.0f free=%.0f" % [feeding_cap, free_cap])
	await _teardown(ctx)


func _init() -> void:
	await _frames(2)
	if not has_method("_case_completes"):
		quit(1)
		return
	await _case_completes()
	await _case_release_resets()
	await _case_leaving_range_resets()
	await _case_no_double_absorb()
	await _case_damage_cancels()
	await _case_feeding_slows()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] absorption_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
