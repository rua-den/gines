extends SceneTree
## Headless regression check: the M4 energy loop around the spike burst.
##
## Contract (see player.gd):
##   * A fresh player starts with a full energy pool.
##   * One accepted burst spends exactly BURST_ENERGY_COST energy.
##   * A burst is rejected — with no energy spent and no damage dealt — before
##     evolution, while the cooldown holds, or when energy is below the cost.
##   * Energy regenerates with elapsed time and never exceeds MAX_ENERGY.
##   * Pausing the game does not regenerate energy.
##   * Revive refills energy; energy is not written to the save file.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/energy_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 9

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


func _case_starts_full() -> void:
	var p := _make_player()
	await _frames(2)
	var ok: bool = is_equal_approx(p.energy, p.MAX_ENERGY) and p.MAX_ENERGY > 0.0
	_check("a fresh player starts with full energy", ok,
		"energy=%.2f max=%.2f" % [p.energy, p.MAX_ENERGY])
	p.queue_free()
	await _frames(2)


func _case_burst_spends_cost() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p) # 60 px: inside BURST_RANGE
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var before: float = p.energy
	var fired := p.spike_burst()
	var after: float = p.energy # measured before regeneration ticks
	await _frames(2)
	var ok: bool = fired and is_equal_approx(after, before - p.BURST_ENERGY_COST) \
		and pred.health == Predator.MAX_HEALTH - 1
	_check("one burst spends exactly its energy cost", ok,
		"fired=%s after=%.2f before=%.2f cost=%.2f predator_health=%d" % [
			fired, after, before, p.BURST_ENERGY_COST, pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_no_burst_before_evolution() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p)
	var before: float = p.energy
	var fired := p.spike_burst()
	await _frames(2)
	var ok: bool = not fired and is_equal_approx(p.energy, before) \
		and pred.health == Predator.MAX_HEALTH
	_check("no energy is spent before evolution", ok,
		"fired=%s energy=%.2f before=%.2f predator_health=%d" % [
			fired, p.energy, before, pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_cooldown_rejection_costs_nothing() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p) # inside BURST_RANGE
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var first := p.spike_burst()
	var after_first: float = p.energy
	var second := p.spike_burst()
	var after_second: float = p.energy # no frame elapsed: only the spend may change it
	await _frames(2)
	var ok: bool = first and not second \
		and is_equal_approx(after_first, p.MAX_ENERGY - p.BURST_ENERGY_COST) \
		and is_equal_approx(after_second, after_first) \
		and pred.health == Predator.MAX_HEALTH - 1
	_check("a cooldown-blocked burst spends no energy", ok,
		"first=%s second=%s after_first=%.2f after_second=%.2f predator_health=%d" % [
			first, second, after_first, after_second, pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_starved_rejection() -> void:
	var p := _make_player()
	var pred := _make_predator(Vector2(560, 500), p)
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	# Below the cost but above zero, so a spend that ignores affordability
	# would be visible instead of clamping to zero.
	p.energy = 0.5
	var fired := p.spike_burst()
	var ok: bool = not fired and is_equal_approx(p.energy, 0.5) \
		and pred.health == Predator.MAX_HEALTH
	_check("an energy-starved burst is rejected", ok,
		"fired=%s energy=%.2f predator_health=%d" % [
			fired, p.energy, pred.health])
	pred.queue_free()
	p.queue_free()
	await _frames(2)


func _case_regeneration_capped() -> void:
	var p := _make_player()
	p.energy = p.MAX_ENERGY - 0.5
	await _frames(60) # ~1 s at the default 60 Hz physics tick
	var near_cap: float = p.energy
	var capped: bool = near_cap <= p.MAX_ENERGY and near_cap > p.MAX_ENERGY - 0.5
	p.energy = 0.0
	await _frames(60)
	var recovered: float = p.energy
	var ok: bool = capped and recovered >= 0.9 and recovered <= p.MAX_ENERGY
	_check("energy regenerates and stays capped", ok,
		"near_cap=%.2f recovered=%.2f max=%.2f" % [near_cap, recovered, p.MAX_ENERGY])
	p.queue_free()
	await _frames(2)


func _case_pause_does_not_regenerate() -> void:
	var path := "user://test_energy_pause.cfg"
	SaveState.clear(path)
	var scene: Node = load("res://scenes/prototype.tscn").instantiate()
	scene.set("_save_path", path)
	get_root().add_child(scene)
	await _frames(3)
	var p: PlayerController = scene.player
	p.energy = 0.0
	paused = true
	await _frames(30)
	var during: float = p.energy
	paused = false
	await _frames(2)
	var ok: bool = is_zero_approx(during)
	_check("pause does not regenerate energy", ok,
		"energy_after_pause=%.2f" % during)
	SaveState.clear(path)
	scene.queue_free()
	await _frames(2)


func _case_save_omits_energy() -> void:
	var path := "user://test_energy_save.cfg"
	SaveState.clear(path)
	var scene: Node = load("res://scenes/prototype.tscn").instantiate()
	scene.set("_save_path", path)
	get_root().add_child(scene)
	await _frames(3)
	var p: PlayerController = scene.player
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	p.energy = 0.0
	scene._save_progress()
	var data := SaveState.read(path)
	var fresh := _make_player()
	await _frames(2)
	var ok: bool = data.get("evolved", false) and not data.has("energy") \
		and is_equal_approx(fresh.energy, fresh.MAX_ENERGY)
	_check("energy is not written to the save", ok,
		"keys=%s fresh_energy=%.2f" % [data.keys(), fresh.energy])
	fresh.queue_free()
	scene.queue_free()
	SaveState.clear(path)
	await _frames(3)


func _case_revive_refills() -> void:
	var p := _make_player()
	p.energy = 0.0
	p.health = 1
	p.revive()
	await _frames(2)
	var ok: bool = is_equal_approx(p.energy, p.MAX_ENERGY) and p.health == p.MAX_HEALTH
	_check("revive refills energy", ok,
		"energy=%.2f max=%.2f health=%d/%d" % [
			p.energy, p.MAX_ENERGY, p.health, p.MAX_HEALTH])
	p.queue_free()
	await _frames(2)


func _init() -> void:
	await _frames(2)
	await _case_starts_full()
	await _case_burst_spends_cost()
	await _case_no_burst_before_evolution()
	await _case_cooldown_rejection_costs_nothing()
	await _case_starved_rejection()
	await _case_regeneration_capped()
	await _case_pause_does_not_regenerate()
	await _case_save_omits_energy()
	await _case_revive_refills()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] energy_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
