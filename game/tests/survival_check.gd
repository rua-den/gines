extends SceneTree
## Headless regression check: damage, defeat, revive and predator behaviour (M2).
##
## Contract (see player.gd / predator.gd):
##   A predator within TOUCH_RANGE damages the player once; INVULN_TIME blocks
##   further hits; three hits defeat the player (one `died` signal); revive()
##   restores full health. The predator chases inside DETECT_RANGE and patrols
##   at PATROL_SPEED outside it.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/survival_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 6
const INVULN_FRAMES := 70 # > INVULN_TIME (1.0 s at 60 Hz)

var _passed := 0
var _failed := 0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _make_player(pos: Vector2) -> PlayerController:
	var p: PlayerController = load("res://scenes/player.tscn").instantiate()
	p.position = pos
	p.demo_active = true
	p.demo_dir = Vector2.ZERO
	get_root().add_child(p)
	return p


func _make_predator(pos: Vector2, player: PlayerController) -> Predator:
	var pred := Predator.new()
	pred.position = pos
	pred.player = player
	pred.patrol_min_x = pos.x - 150.0
	pred.patrol_max_x = pos.x + 150.0
	get_root().add_child(pred)
	return pred


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


func _case_contact_damage() -> void:
	var p := _make_player(Vector2(500, 500))
	var pred := _make_predator(Vector2(550, 500), p) # 50 px < TOUCH_RANGE
	await _frames(5)
	var ok := p.health == p.MAX_HEALTH - 1 and not p.dead
	_check("predator contact costs one health", ok, "health=%d/%d" % [p.health, p.MAX_HEALTH])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_invuln_blocks() -> void:
	var p := _make_player(Vector2(500, 500))
	var first := p.take_damage(1, Vector2(560, 500))
	var second := p.take_damage(1, Vector2(560, 500))
	await _frames(3)
	var ok := first and not second and p.health == p.MAX_HEALTH - 1
	_check("invulnerability blocks the next hit", ok,
		"first=%s second=%s health=%d" % [first, second, p.health])
	p.queue_free()
	await _frames(2)


func _case_invuln_expires() -> void:
	var p := _make_player(Vector2(500, 500))
	p.take_damage(1, Vector2(560, 500))
	await _frames(INVULN_FRAMES)
	var landed := p.take_damage(1, Vector2(560, 500))
	await _frames(2)
	var ok := landed and p.health == p.MAX_HEALTH - 2
	_check("invulnerability expires", ok, "landed=%s health=%d" % [landed, p.health])
	p.queue_free()
	await _frames(2)


func _case_death_and_signal() -> void:
	var p := _make_player(Vector2(500, 500))
	var deaths := [0]
	p.died.connect(func() -> void: deaths[0] += 1)
	for i in p.MAX_HEALTH:
		p.take_damage(1, Vector2(560, 500))
		await _frames(INVULN_FRAMES)
	await _frames(3)
	var ok: bool = p.dead and p.health == 0 and deaths[0] == 1
	_check("three hits defeat once", ok, "dead=%s health=%d died_signals=%d" % [p.dead, p.health, deaths[0]])
	p.queue_free()
	await _frames(2)


func _case_revive() -> void:
	var p := _make_player(Vector2(500, 500))
	for i in p.MAX_HEALTH:
		p.take_damage(1, Vector2(560, 500))
		await _frames(INVULN_FRAMES)
	p.revive()
	await _frames(2)
	var ok := not p.dead and p.health == p.MAX_HEALTH and p.state_name() == "SWIM"
	_check("revive restores the player", ok, "dead=%s health=%d state=%s" % [p.dead, p.health, p.state_name()])
	p.queue_free()
	await _frames(2)


func _case_predator_behaviour() -> void:
	var p := _make_player(Vector2(500, 500))
	var pred := _make_predator(Vector2(800, 500), p) # 300 px: inside DETECT_RANGE
	await _frames(3)
	var start_dist := pred.global_position.distance_to(p.global_position)
	await _frames(30)
	var chased := pred.chasing and pred.global_position.distance_to(p.global_position) < start_dist - 10.0
	# Now remove the player from detection range and let the patrol resume.
	p.position = Vector2(500, 2000)
	await _frames(20)
	var patrolled := not pred.chasing and absf(pred.velocity.x) <= Predator.PATROL_SPEED + 0.5
	var ok := chased and patrolled
	_check("predator chases, then patrols", ok,
		"chased=%s patrolled=%s vx=%.0f" % [chased, patrolled, pred.velocity.x])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _init() -> void:
	await _frames(2)
	await _case_contact_damage()
	await _case_invuln_blocks()
	await _case_invuln_expires()
	await _case_death_and_signal()
	await _case_revive()
	await _case_predator_behaviour()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] survival_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
