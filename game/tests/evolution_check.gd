extends SceneTree
## Headless regression check: evolution requirement, ability gating and save/load (M3).
##
## Contract (see player.gd / predator.gd / save_state.gd):
##   * Evolution needs EVOLVE_COST nutrition, can happen once, and consumes the cost.
##   * The offensive burst does nothing before evolution; afterwards it damages
##     predators in range, on a cooldown, and defeating one fires exactly one signal.
##   * Progress written to a save path reads back and can be applied to a player.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/evolution_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 11
const TEST_SAVE := "user://test_evolution_save.cfg"

var _passed := 0
var _failed := 0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _make_player(pos := Vector2(500, 500)) -> PlayerController:
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


func _case_cost_gate() -> void:
	var p := _make_player()
	p.nutrition = p.EVOLVE_COST - 1.0
	var can := p.can_evolve()
	var did := p.evolve()
	await _frames(2)
	var ok := not can and not did and not p.evolved
	_check("below the cost evolution is refused", ok,
		"can=%s did=%s evolved=%s" % [can, did, p.evolved])
	p.queue_free()
	await _frames(2)


func _case_evolves_once() -> void:
	var p := _make_player()
	p.nutrition = p.EVOLVE_COST
	var did := p.evolve()
	var after := p.nutrition
	var again := p.evolve()
	await _frames(2)
	var ok := did and p.evolved and is_zero_approx(after) and not again
	_check("evolution costs nutrition and happens once", ok,
		"did=%s evolved=%s nutrition_after=%.1f again=%s" % [did, p.evolved, after, again])
	p.queue_free()
	await _frames(2)


func _case_no_attack_before() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p) # 60 px: inside BURST_RANGE
	var fired := p.spike_burst()
	await _frames(2)
	var ok := not fired and pred.health == Predator.MAX_HEALTH
	_check("the burst is unavailable before evolution", ok,
		"fired=%s predator_health=%d" % [fired, pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_attack_after() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p)
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var fired := p.spike_burst()
	await _frames(2)
	var ok := fired and pred.health == Predator.MAX_HEALTH - 1
	_check("the burst damages a predator after evolution", ok,
		"fired=%s predator_health=%d" % [fired, pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_out_of_range() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(900, 500), p) # 400 px: outside BURST_RANGE
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	p.spike_burst()
	await _frames(2)
	var ok := pred.health == Predator.MAX_HEALTH
	_check("the burst spares predators out of range", ok, "predator_health=%d" % pred.health)
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_cooldown() -> void:
	var p := _make_player()
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var first := p.spike_burst()
	var second := p.spike_burst()
	await _frames(2)
	var ok := first and not second
	_check("a second burst waits for the cooldown", ok, "first=%s second=%s" % [first, second])
	p.queue_free()
	await _frames(2)


func _case_defeat_signal() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p)
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var defeats := [0]
	pred.killed.connect(func() -> void: defeats[0] += 1)
	p.spike_burst()
	await _frames(60) # > BURST_COOLDOWN
	p.spike_burst()
	await _frames(3)
	var ok: bool = pred.defeated and defeats[0] == 1
	_check("two bursts defeat the predator once", ok,
		"defeated=%s signals=%d health=%d" % [pred.defeated, defeats[0], pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_evolve_grace() -> void:
	var p := _make_player()
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	p.grant_grace(1.5)
	var landed := p.take_damage(1, p.global_position + Vector2(40, 0))
	await _frames(2)
	var ok := not landed and p.health == p.MAX_HEALTH
	_check("the transformation grants a grace window", ok,
		"hit_landed=%s health=%d/%d" % [landed, p.health, p.MAX_HEALTH])
	p.queue_free()
	await _frames(2)


func _case_shockwave() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(520, 500), p) # 20 px: on top of the player
	var moved := pred.shove_away_from(p.global_position, 120.0)
	var dist := pred.global_position.distance_to(p.global_position)
	var health_before := p.health
	await _frames(30) # 0.5 s: still reeling, so it must not close in or bite
	var held := pred.global_position.distance_to(p.global_position)
	var closer := pred.shove_away_from(p.global_position, 60.0)
	var ok: bool = moved > 0.0 and is_equal_approx(dist, 120.0) and is_equal_approx(held, 120.0) \
		and p.health == health_before and is_zero_approx(closer)
	_check("the evolution shockwave pushes a predator out", ok,
		"moved=%.0f dist=%.0f after_0.5s=%.0f health=%d/%d" % [moved, dist, held, p.health, health_before])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_scene_save_flow() -> void:
	var path := "user://test_scene_save.cfg"
	SaveState.clear(path)
	var first: Node = load("res://scenes/prototype.tscn").instantiate()
	first.set("_save_path", path)
	get_root().add_child(first)
	await _frames(3)
	first.player.nutrition = first.player.EVOLVE_COST
	first.player.global_position = first.zone.global_position
	var did: bool = first._try_evolve()
	await _frames(3)
	var saved: bool = bool(SaveState.read(path).get("evolved", false))
	var second: Node = load("res://scenes/prototype.tscn").instantiate()
	second.set("_save_path", path)
	get_root().add_child(second)
	await _frames(3)
	var ok: bool = did and saved and second.player.evolved and second.zone.used
	_check("a new scene run loads the evolved body", ok,
		"evolved_in_run=%s saved=%s reloaded=%s alcove_used=%s" % [
			did, saved, second.player.evolved, second.zone.used])
	first.queue_free()
	second.queue_free()
	SaveState.clear(path)
	await _frames(3)


func _case_save_roundtrip() -> void:
	SaveState.clear(TEST_SAVE)
	var written := SaveState.write(TEST_SAVE, {"evolved": true, "nutrition": 12.5})
	var data := SaveState.read(TEST_SAVE)
	var p := _make_player()
	SaveState.apply_to_player(p, data)
	await _frames(2)
	var ok: bool = written == OK and data.get("evolved", false) and p.evolved and is_equal_approx(p.nutrition, 12.5)
	_check("evolution survives a save/load cycle", ok,
		"write=%s evolved=%s nutrition=%.1f" % [written, p.evolved, p.nutrition])
	SaveState.clear(TEST_SAVE)
	p.queue_free()
	await _frames(2)


func _init() -> void:
	await _frames(2)
	await _case_cost_gate()
	await _case_evolves_once()
	await _case_no_attack_before()
	await _case_attack_after()
	await _case_out_of_range()
	await _case_cooldown()
	await _case_defeat_signal()
	await _case_evolve_grace()
	await _case_shockwave()
	await _case_scene_save_flow()
	await _case_save_roundtrip()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] evolution_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
