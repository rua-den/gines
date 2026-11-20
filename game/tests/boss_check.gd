extends SceneTree
## Headless regression check: the M5 boss state machine and damage gating.
##
## Contract (see bloom_boss.gd):
##   * The boss takes body damage only while `phase == "exposed"`.
##   * A refused hit deals nothing and emits nothing.
##   * Defeat emits `defeated` exactly once and freezes the boss.
##   * The boss hurts the player only during the `attack` phase (once per phase).
##   * `reset()` restores health, defeat state and phase.
##   * The boss joins the "predator" group so spike_burst() can reach it —
##     one accepted burst spends exactly one energy and one boss health,
##     and starved / cooldown bursts have no side effects.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/boss_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 12
const TEST_SAVE := "user://test_boss_arena_save.cfg"

const INVULN_FRAMES := 75 # > PlayerController.INVULN_TIME at 60 Hz, < WEAK_WINDOW

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


func _make_boss(pos: Vector2, player: PlayerController) -> BloomBoss:
	var boss := BloomBoss.new()
	boss.position = pos
	boss.set_player(player)
	get_root().add_child(boss)
	return boss


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


func _case_exposed_is_only_vulnerable_phase() -> void:
	var p := _make_player()
	var boss := _make_boss(Vector2(500, 500), p)
	boss.phase = "exposed"
	var first: bool = boss.take_damage(1)
	var after_first: int = boss.health
	boss.phase = "telegraph"
	var second: bool = boss.take_damage(1)
	var after_second: int = boss.health
	var ok: bool = first and after_first == BloomBoss.MAX_HEALTH - 1 \
		and not second and after_second == after_first
	_check("exposed window is the only vulnerable phase", ok,
		"first=%s hp=%d second=%s hp=%d" % [first, after_first, second, after_second])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_refusal_emits_nothing() -> void:
	var p := _make_player()
	var boss := _make_boss(Vector2(500, 500), p)
	var emissions := [0]
	boss.defeated.connect(func(): emissions[0] += 1)
	boss.phase = "idle"
	var before: int = boss.health
	var fired: bool = boss.take_damage(2)
	var ok: bool = not fired and boss.health == before \
		and not boss.is_defeated and emissions[0] == 0
	_check("refusal deals no damage and emits nothing", ok,
		"fired=%s hp=%d defeated=%s emissions=%d" % [
			fired, boss.health, boss.is_defeated, emissions[0]])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_defeat_emits_once_and_freezes() -> void:
	var p := _make_player()
	var boss := _make_boss(Vector2(500, 500), p)
	var emissions := [0]
	boss.defeated.connect(func(): emissions[0] += 1)
	boss.health = 1
	boss.phase = "exposed"
	var first: bool = boss.take_damage(1)
	var second: bool = boss.take_damage(1)
	var ok: bool = first and not second and emissions[0] == 1 \
		and boss.is_defeated and boss.health == 0
	_check("defeat emits once and freezes the boss", ok,
		"first=%s second=%s emissions=%d defeated=%s hp=%d" % [
			first, second, emissions[0], boss.is_defeated, boss.health])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_player_hurt_only_during_attack() -> void:
	var p := _make_player(Vector2(520, 500)) # 20 px from the boss, inside RADIUS
	var boss := _make_boss(Vector2(500, 500), p)
	boss.phase = "attack"
	await _frames(1)
	var after_attack: int = p.health
	p.revive()
	# Switch to exposed immediately so no further attack can land, then wait out
	# invulnerability: otherwise the exposed check would pass vacuously.
	boss.phase = "exposed"
	await _frames(INVULN_FRAMES)
	var after_exposed: int = p.health
	var ok: bool = after_attack == PlayerController.MAX_HEALTH - 1 \
		and after_exposed == PlayerController.MAX_HEALTH
	_check("player is hurt only during the attack phase", ok,
		"after_attack=%d after_exposed=%d max=%d invuln_frames=%d" % [
			after_attack, after_exposed, PlayerController.MAX_HEALTH, INVULN_FRAMES])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_reset_restores() -> void:
	var p := _make_player()
	var boss := _make_boss(Vector2(500, 500), p)
	boss.health = 1
	boss.phase = "exposed"
	boss.take_damage(1)
	boss.reset()
	var ok: bool = boss.health == BloomBoss.MAX_HEALTH \
		and not boss.is_defeated and boss.phase == "idle"
	_check("reset restores health and phase", ok,
		"hp=%d defeated=%s phase=%s" % [boss.health, boss.is_defeated, boss.phase])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_burst_spends_one_energy_and_one_health() -> void:
	var p := _make_player(Vector2(560, 500)) # 60 px, inside BURST_RANGE
	var boss := _make_boss(Vector2(500, 500), p)
	boss.phase = "exposed"
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var energy_before: float = p.energy
	var hp_before: int = boss.health
	var fired: bool = p.spike_burst()
	var energy_after: float = p.energy # measured before regeneration ticks
	var hp_after: int = boss.health
	await _frames(2)
	var ok: bool = fired and hp_after == hp_before - 1 \
		and is_equal_approx(energy_after,
			energy_before - PlayerController.BURST_ENERGY_COST)
	_check("a fired burst in the exposed window spends exactly one energy and one boss health", ok,
		"fired=%s hp=%d->%d energy=%.2f->%.2f cost=%.2f" % [
			fired, hp_before, hp_after, energy_before, energy_after,
			PlayerController.BURST_ENERGY_COST])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_burst_outside_window_spends_energy_but_deals_no_damage() -> void:
	var p := _make_player(Vector2(560, 500)) # 60 px, inside BURST_RANGE
	var boss := _make_boss(Vector2(500, 500), p)
	boss.phase = "telegraph" # NOT exposed: the burst must spend energy but land nothing
	p.nutrition = p.EVOLVE_COST
	p.evolve()
	var energy_before: float = p.energy
	var hp_before: int = boss.health
	var fired: bool = p.spike_burst()
	var energy_after: float = p.energy # measured before regeneration ticks
	var hp_after: int = boss.health
	await _frames(2)
	var ok: bool = fired \
		and is_equal_approx(energy_after,
			energy_before - PlayerController.BURST_ENERGY_COST) \
		and hp_after == hp_before
	_check("a burst outside the window spends energy but deals no boss damage", ok,
		"fired=%s hp=%d->%d energy=%.2f->%.2f cost=%.2f" % [
			fired, hp_before, hp_after, energy_before, energy_after,
			PlayerController.BURST_ENERGY_COST])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_starved_and_cooldown_bursts_have_no_effects() -> void:
	var p := _make_player(Vector2(560, 500)) # inside BURST_RANGE
	var boss := _make_boss(Vector2(500, 500), p)
	boss.phase = "exposed"
	p.evolved = true
	p.energy = 0.0
	var starved: bool = p.spike_burst()
	var hp_after_starved: int = boss.health
	var energy_after_starved: float = p.energy
	p.energy = p.MAX_ENERGY
	var first: bool = p.spike_burst()
	var hp_after_first: int = boss.health
	var energy_after_first: float = p.energy
	var second: bool = p.spike_burst() # immediately: inside the 0.8 s cooldown
	var hp_after_second: int = boss.health
	var energy_after_second: float = p.energy
	await _frames(2)
	var ok: bool = not starved \
		and hp_after_starved == BloomBoss.MAX_HEALTH \
		and is_zero_approx(energy_after_starved) \
		and first and hp_after_first == BloomBoss.MAX_HEALTH - 1 \
		and is_equal_approx(energy_after_first,
			p.MAX_ENERGY - PlayerController.BURST_ENERGY_COST) \
		and not second and hp_after_second == hp_after_first \
		and is_equal_approx(energy_after_second, energy_after_first)
	_check("starved and cooldown bursts have no side effects", ok,
		"starved=%s hp=%d first=%s hp=%d second=%s hp=%d energy=%.2f" % [
			starved, hp_after_starved, first, hp_after_first,
			second, hp_after_second, energy_after_second])
	boss.queue_free()
	p.queue_free()
	await _frames(2)


func _case_room_builder_matches_prototype_layout() -> void:
	var host := Node2D.new()
	get_root().add_child(host)
	var room := Rect2(0, 0, 1920, 1080)
	var floor_top := 1020.0
	RoomBuilder.build_room(host, room, floor_top, [])
	var bodies: Array[StaticBody2D] = []
	for child in host.get_children():
		if child is StaticBody2D:
			bodies.append(child)
	var expected_floor := Rect2(0, floor_top, room.size.x, room.size.y - floor_top)
	var floor_bounds := Rect2()
	if not bodies.is_empty():
		var shape_node: CollisionShape2D = bodies[0].get_child(0) as CollisionShape2D
		if shape_node != null:
			var shape: RectangleShape2D = shape_node.shape as RectangleShape2D
			if shape != null:
				floor_bounds = Rect2(shape_node.position - shape.size / 2.0, shape.size)
	var ok: bool = bodies.size() == 6 \
		and floor_bounds.position.is_equal_approx(expected_floor.position) \
		and floor_bounds.size.is_equal_approx(expected_floor.size)
	_check("room builder matches the prototype slab layout", ok,
		"bodies=%d floor=%s expected=%s" % [bodies.size(), floor_bounds, expected_floor])
	host.queue_free()
	await _frames(2)


# ------------------------------------------------------- arena / gate / retry

## Instantiates the real arena scene with an isolated save path so a stale
## profile can never make the gate open before the case says so.
func _make_fight() -> Node:
	var packed: PackedScene = load("res://scenes/boss_test.tscn")
	if packed == null:
		return null
	var fight: Node = packed.instantiate()
	fight.set("_save_path", TEST_SAVE)
	get_root().add_child(fight)
	return fight


func _case_gate_blocks_unevolved() -> void:
	var fight: Node = _make_fight()
	if fight == null:
		_check("gate blocks an unevolved player", false, "missing BossFight scene")
		return
	await _frames(2)
	fight.player.nutrition = 0.0
	var boss = fight.boss
	var before: int = boss.health
	# Force the exposed phase so the only reason no damage lands is the gate.
	boss.phase = "exposed"
	var fired: bool = fight.player.spike_burst()
	var ok: bool = not fight.gate_open() and boss.player == null \
		and not fired and boss.health == before
	_check("gate blocks an unevolved player", ok,
		"gate_open=%s boss_player=%s fired=%s hp=%d->%d" % [
			fight.gate_open(), boss.player, fired, before, boss.health])
	fight.queue_free()
	SaveState.clear(TEST_SAVE)
	await _frames(2)


func _case_gate_opens_after_evolution() -> void:
	var fight: Node = _make_fight()
	if fight == null:
		_check("gate opens after evolution", false, "missing BossFight scene")
		return
	await _frames(2)
	fight.player.nutrition = fight.player.EVOLVE_COST
	var did: bool = fight.player.evolve()
	await _frames(2)
	var ok: bool = did and fight.gate_open() and fight.boss.player == fight.player
	_check("gate opens after evolution", ok,
		"evolved=%s gate_open=%s boss_player=%s" % [
			did, fight.gate_open(), fight.boss.player])
	fight.queue_free()
	SaveState.clear(TEST_SAVE)
	await _frames(2)


func _case_shelter_retry_keeps_progress() -> void:
	var fight: Node = _make_fight()
	if fight == null:
		_check("shelter retry resets the fight but keeps progress", false, "missing BossFight scene")
		return
	await _frames(2)
	fight.player.nutrition = fight.player.EVOLVE_COST
	fight.player.evolve()
	await _frames(2)
	var boss = fight.boss
	boss.phase = "exposed"
	boss.take_damage(4) # 6 -> 2, so reset() has something to restore
	fight.player.nutrition = 42.0
	fight.player.take_damage(PlayerController.MAX_HEALTH, Vector2.ZERO)
	fight.retry()
	var ok: bool = fight.player.health == PlayerController.MAX_HEALTH \
		and is_equal_approx(fight.player.energy, PlayerController.MAX_ENERGY) \
		and boss.health == BloomBoss.MAX_HEALTH \
		and fight.player.evolved \
		and is_equal_approx(fight.player.nutrition, 42.0)
	_check("shelter retry resets the fight but keeps progress", ok,
		"hp=%d energy=%.2f boss_hp=%d evolved=%s nutrition=%.1f" % [
			fight.player.health, fight.player.energy, boss.health,
			fight.player.evolved, fight.player.nutrition])
	fight.queue_free()
	SaveState.clear(TEST_SAVE)
	await _frames(2)


func _init() -> void:
	await _frames(2)
	await _case_exposed_is_only_vulnerable_phase()
	await _case_refusal_emits_nothing()
	await _case_defeat_emits_once_and_freezes()
	await _case_player_hurt_only_during_attack()
	await _case_reset_restores()
	await _case_burst_spends_one_energy_and_one_health()
	await _case_burst_outside_window_spends_energy_but_deals_no_damage()
	await _case_starved_and_cooldown_bursts_have_no_effects()
	await _case_room_builder_matches_prototype_layout()
	SaveState.clear(TEST_SAVE)
	await _case_gate_blocks_unevolved()
	await _case_gate_opens_after_evolution()
	await _case_shelter_retry_keeps_progress()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] boss_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
