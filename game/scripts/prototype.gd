extends Node2D
## Milestone 2 — absorption & survival prototype, extended by M3 evolution and
## the M4 energy loop.
##
## The Milestone 1 movement room (same 1920x1080 geometry) plus the first loop
## that can be lost:
##   * four nutrient motes — hold `interact` in range for 0.75 s to feed
##   * one predator — patrols, chases within 420 px, hurts on contact
##   * three health, one second of invulnerability, knockback
##   * defeat -> "press E to retry" overlay -> in-place respawn
##
## Play:  godot --path game res://scenes/prototype.tscn
## Demo:  godot --path game res://scenes/prototype.tscn -- --m2-demo --outdir=<abs>
## The demo autopilots feed -> get hit -> get defeated -> retry, saves three
## screenshots, and exits 1 when any criterion fails (same contract as M1).

const ROOM := Rect2(0, 0, 1920, 1080)
const FLOOR_TOP := 1020.0
const START_POS := Vector2(300, 500)
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const MOTE_START := [
	Vector2(520, 470),
	Vector2(960, 560),
	Vector2(1600, 880),
	Vector2(1240, 300),
]
const PREDATOR_START := Vector2(1180, 560)
const ZONE_POS := Vector2(1720, 420)
const KILL_REWARD := 15.0
const DEMO_SHOTS := 3
# Named, not counted: a duplicated screenshot cannot stand in for a missing one.
const M3_SHOTS := ["requirement", "evolve", "burst", "kill"]
# Agent-proposed (not owner-approved): the transformation itself grants a short
# grace window and pushes nearby cells out, so the first evolution moment is a
# beat rather than an immediate brawl.
const EVOLVE_GRACE := 1.5
const EVOLVE_SHOCK_RADIUS := 120.0
const DEMO_BOUNDS := Rect2(60, 60, 1800, 960)
const DEMO_TIMEOUT := 20.0

const BG := Color(0.05, 0.16, 0.18)
const SLAB := Color(0.10, 0.32, 0.30)
const SLAB_EDGE := Color(0.56, 0.96, 0.89)
const GOLD := Color(0.95, 0.76, 0.31)
const TEAL_LIGHT := Color(0.56, 0.96, 0.89)
const CORAL := Color(0.95, 0.48, 0.42)

var player: PlayerController
var predator: Predator
var camera: Camera2D
var zone: EvolutionZone
var motes: Array[Absorbable] = []

var health_label: Label
var nutrition_label: Label
var state_label: Label
var evolution_label: Label
var energy_label: Label
var retry_label: Label
var demo_label: Label
var pause_label: Label

# Observed run facts (HUD + demo verdict).
var absorbed := 0
var hits := 0
var retries := 0
var predator_defeated := false

var _paused := false
var _flash := 0.0
var _anim := 0.0
var _save_path := SaveState.DEFAULT_PATH
var _fresh_save := false

# Demo mode.
var demo := false
var m3_demo := false
var outdir := ""
var _stage := 0
var _stage_timer := 0.0
var _pending_capture := ""
var _capture_timer := 0.0
var _captured: Array[String] = []
var _min_pos := Vector2.INF
var _max_pos := Vector2(-INF, -INF)
var _bursts := 0
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[M2] READY prototype, viewport ", get_viewport_rect().size)
	for a in OS.get_cmdline_user_args():
		if a == "--m2-demo":
			demo = true
		elif a == "--m3-demo":
			demo = true
			m3_demo = true
		elif a == "--fresh-save":
			_fresh_save = true
		elif a.begins_with("--outdir="):
			outdir = a.trim_prefix("--outdir=")
	if _fresh_save:
		SaveState.clear(_save_path)
	_build_background()
	_build_room()
	_build_zone()
	_build_player()
	_build_motes()
	_build_predator()
	_build_camera()
	_build_hud()
	_load_progress()
	if demo:
		player.demo_active = true
		print("[M2] demo mode, outdir=", outdir, " m3=", m3_demo)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_paused = not _paused
		get_tree().paused = _paused
		pause_label.visible = _paused


func _process(delta: float) -> void:
	_anim += delta
	_flash = maxf(_flash - delta, 0.0)
	if _paused:
		return
	_min_pos = _min_pos.min(player.global_position)
	_max_pos = _max_pos.max(player.global_position)
	camera.global_position = player.global_position
	_update_hud()
	if not player.dead and not demo and Input.is_action_just_pressed("interact"):
		_try_evolve()
	if player.dead and not demo and Input.is_action_just_pressed("interact"):
		_retry()
	if demo and not _done:
		if m3_demo:
			_m3_demo_update(delta)
		else:
			_demo_update(delta)
	if _pending_capture != "":
		_capture_timer -= delta
		if _capture_timer <= 0.0:
			_save_capture(_pending_capture)
			_pending_capture = ""


# ------------------------------------------------------------------ gameplay

func _on_nutrition(_amount: float) -> void:
	absorbed += 1
	_flash = 0.35


func _on_damaged(_hits_left: int) -> void:
	hits += 1
	_flash = 0.35


func _on_died() -> void:
	retry_label.visible = true
	retry_label.text = "Absorbed — press E to retry"


func _retry() -> void:
	player.global_position = START_POS
	player.revive()
	retries += 1
	retry_label.visible = false
	camera.global_position = START_POS
	print("[M2] retry #", retries)


## Evolution site activation. Kept on the scene so the rule (player.can_evolve)
## lives in exactly one place; returns false when nothing happened.
func _try_evolve() -> bool:
	if player.evolved or not zone.in_range(player.global_position):
		return false
	if not player.can_evolve():
		_flash = 0.35
		print("[M3] evolution refused: %d/%d nutrition" % [int(player.nutrition), int(player.EVOLVE_COST)])
		return false
	player.evolve()
	zone.mark_used()
	player.grant_grace(EVOLVE_GRACE)
	# The transformation itself creates space: nearby organisms are pushed out.
	for node in get_tree().get_nodes_in_group(Predator.GROUP):
		if node.has_method("shove_away_from"):
			node.shove_away_from(player.global_position, EVOLVE_SHOCK_RADIUS)
	_flash = 0.5
	_save_progress()
	print("[M3] evolved; nutrition now ", player.nutrition)
	return true


func _on_killed() -> void:
	predator_defeated = true
	player.nutrition += KILL_REWARD
	_flash = 0.35
	_save_progress()
	print("[M3] predator defeated, +", KILL_REWARD, " nutrition")
	get_tree().create_timer(0.6).timeout.connect(_remove_predator)


func _remove_predator() -> void:
	if predator != null and is_instance_valid(predator):
		predator.queue_free()
	predator = null


func _save_progress() -> void:
	# Demo runs never touch the player's real save.
	if demo:
		return
	SaveState.write(_save_path, {"evolved": player.evolved, "nutrition": player.nutrition})


func _load_progress() -> void:
	if demo:
		return
	var data := SaveState.read(_save_path)
	if data.is_empty():
		return
	SaveState.apply_to_player(player, data)
	if player.evolved:
		zone.mark_used()
		print("[M3] loaded saved progress: evolved=true nutrition=", player.nutrition)


# ------------------------------------------------------------------ build

func _radial_texture(stops: Array) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, stops[0][1])
	grad.set_color(1, stops[stops.size() - 1][1])
	for i in range(1, stops.size() - 1):
		grad.add_point(stops[i][0], stops[i][1])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	return tex


func _build_background() -> void:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -2
	add_child(backdrop)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(bg)
	var blob_tex := _radial_texture([
		[0.0, Color(0.16, 0.42, 0.38, 0.5)],
		[1.0, Color(0.16, 0.42, 0.38, 0.0)],
	])
	# Static, sparse: gameplay reading beats ambient spectacle in the prototype.
	for def in [[Vector2(420, 320), 2.4], [Vector2(1250, 260), 2.0], [Vector2(1650, 760), 2.2]]:
		var s := Sprite2D.new()
		s.texture = blob_tex
		s.position = def[0]
		s.scale = Vector2(def[1], def[1])
		add_child(s)


func _add_static_rect(x0: float, y0: float, x1: float, y1: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(x1 - x0, y1 - y0)
	shape.shape = rect
	shape.position = Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0)
	body.add_child(shape)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])
	poly.color = SLAB
	body.add_child(poly)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0)])
	edge.width = 3.0
	edge.default_color = SLAB_EDGE
	body.add_child(edge)
	add_child(body)


func _build_room() -> void:
	_add_static_rect(0, FLOOR_TOP, 1920, 1080)
	_add_static_rect(0, 0, 1920, 60)
	_add_static_rect(0, 0, 60, 1080)
	_add_static_rect(1860, 0, 1920, 1080)
	_add_static_rect(700, 640, 1200, 680)
	_add_static_rect(1400, 700, 1460, FLOOR_TOP)


func _build_player() -> void:
	player = PLAYER_SCENE.instantiate()
	# The scene root is PROCESS_MODE_ALWAYS so the pause key still works; the
	# player must not inherit that, or movement and energy regeneration keep
	# running behind the PAUSED overlay.
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = START_POS
	add_child(player)
	player.nutrition_gained.connect(_on_nutrition)
	player.damaged.connect(_on_damaged)
	player.died.connect(_on_died)
	player.burst_fired.connect(_on_burst_fired)


## The burst's only feedback until there is audio: one expanding ring per shot.
func _on_burst_fired(at: Vector2) -> void:
	_bursts += 1
	var ring := BurstRing.new()
	ring.target_radius = PlayerController.BURST_RANGE
	add_child(ring)
	ring.global_position = at


func _build_zone() -> void:
	zone = EvolutionZone.new()
	zone.position = ZONE_POS
	add_child(zone)


func _build_motes() -> void:
	for i in MOTE_START.size():
		var mote := Absorbable.new()
		mote.position = MOTE_START[i]
		mote.drift_speed = 0.6 + 0.15 * i
		add_child(mote)
		motes.append(mote)


func _build_predator() -> void:
	predator = Predator.new()
	predator.process_mode = Node.PROCESS_MODE_PAUSABLE
	predator.position = PREDATOR_START
	predator.patrol_min_x = 1000.0
	predator.patrol_max_x = 1520.0
	predator.player = player
	predator.killed.connect(_on_killed)
	add_child(predator)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = int(ROOM.position.x)
	camera.limit_top = int(ROOM.position.y)
	camera.limit_right = int(ROOM.end.x)
	camera.limit_bottom = int(ROOM.end.y)
	camera.position = START_POS
	add_child(camera)
	camera.make_current()


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.offset_left = 24
	label.offset_right = 936
	return label


func _make_hud_panel(rect: Rect2, accent: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.09, 0.86)
	style.border_color = Color(0.34, 0.72, 0.68, 0.42)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.border_color = accent
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	# Quiet translucent frames give the prototype HUD a deliberate hierarchy
	# without covering the play space or changing gameplay coordinates.
	var viewport_size := get_viewport_rect().size
	ui.add_child(_make_hud_panel(Rect2(12, 8, 950, 180), CORAL))
	ui.add_child(_make_hud_panel(
		Rect2(12, viewport_size.y - 56, viewport_size.x - 24, 44), TEAL_LIGHT))
	var title := _make_label("GENESIS  /  THE FIRST CELL", 22, Color(0.98, 0.96, 0.93))
	title.offset_top = 12
	title.offset_bottom = 44
	ui.add_child(title)
	health_label = _make_label("Health ♥♥♥", 20, CORAL)
	health_label.offset_top = 48
	health_label.offset_bottom = 76
	ui.add_child(health_label)
	nutrition_label = _make_label("Nutrition 0", 20, GOLD)
	nutrition_label.offset_left = 260
	nutrition_label.offset_right = 700
	nutrition_label.offset_top = 48
	nutrition_label.offset_bottom = 76
	ui.add_child(nutrition_label)
	state_label = _make_label("", 16, TEAL_LIGHT)
	state_label.offset_top = 78
	state_label.offset_bottom = 102
	ui.add_child(state_label)
	evolution_label = _make_label("", 16, GOLD)
	evolution_label.offset_top = 104
	evolution_label.offset_bottom = 128
	ui.add_child(evolution_label)
	# Energy is only meaningful once the body can burst, so it stays hidden
	# before evolution rather than implying a resource the player cannot use.
	energy_label = _make_label("", 16, TEAL_LIGHT)
	energy_label.offset_top = 130
	energy_label.offset_bottom = 154
	energy_label.visible = false
	ui.add_child(energy_label)
	demo_label = _make_label("", 16, GOLD)
	demo_label.offset_top = 156
	demo_label.offset_bottom = 180
	demo_label.visible = demo
	ui.add_child(demo_label)
	var hint := _make_label(
		"WASD — swim  •  hold E near a mote — absorb  •  E at the golden alcove — evolve  •  J — burst  •  Shift — grip  •  Esc — pause",
		15, Color(0.65, 0.8, 0.78))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -36
	hint.offset_bottom = -12
	ui.add_child(hint)
	retry_label = _make_label("Absorbed — press E to retry", 30, GOLD)
	retry_label.anchor_top = 0.5
	retry_label.anchor_bottom = 0.5
	retry_label.offset_top = -24
	retry_label.offset_bottom = 24
	retry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	retry_label.visible = false
	ui.add_child(retry_label)
	pause_label = _make_label("PAUSED — press Esc to resume", 30, GOLD)
	pause_label.anchor_top = 0.5
	pause_label.anchor_bottom = 0.5
	pause_label.offset_top = -24
	pause_label.offset_bottom = 24
	pause_label.visible = false
	ui.add_child(pause_label)


func _update_hud() -> void:
	var pips := ""
	for i in player.MAX_HEALTH:
		pips += "♥" if i < player.health else "·"
	health_label.text = "Health " + pips
	nutrition_label.text = "Nutrition %.0f" % player.nutrition
	# A brief bright pulse is the absorption/hit feedback: no audio yet.
	nutrition_label.modulate = Color(1.6, 1.5, 1.1) if _flash > 0.0 else Color.WHITE
	energy_label.visible = player.evolved
	if player.evolved:
		evolution_label.text = "EVOLVED — ciliated spikes: J to burst"
		evolution_label.modulate = Color(1.0, 0.88, 0.62)
		var energy_pips := ""
		for i in int(player.MAX_ENERGY):
			energy_pips += "●" if i < int(player.energy) else "○"
		energy_label.text = "Energy %s  %.1f/%.0f" % [energy_pips, player.energy, player.MAX_ENERGY]
		energy_label.modulate = Color(1.0, 0.75, 0.65) if player.energy < player.BURST_ENERGY_COST else Color.WHITE
	elif zone.in_range(player.global_position):
		evolution_label.text = "EVOLUTION — press E  (%d/%d nutrition)" % [int(player.nutrition), int(player.EVOLVE_COST)]
		evolution_label.modulate = Color(1.4, 1.2, 0.75) if player.can_evolve() else Color(0.78, 0.72, 0.6)
	else:
		evolution_label.text = "Evolution: golden alcove, far right  (%d/%d nutrition)" % [int(player.nutrition), int(player.EVOLVE_COST)]
		evolution_label.modulate = Color(0.8, 0.75, 0.65)
	var channel := ""
	if player.absorb_target != null:
		channel = "  •  absorbing %d%%" % int(100.0 * player.absorb_target.progress / player.ABSORB_CHANNEL)
	state_label.text = "State: %s  •  speed %.0f px/s%s" % [player.state_name(), player.velocity.length(), channel]


# ------------------------------------------------------------------ demo

func _nearest_mote() -> Absorbable:
	var best: Absorbable = null
	var best_dist := 1e9
	for mote in motes:
		if mote.consumed:
			continue
		var d := player.global_position.distance_to(mote.global_position)
		if d < best_dist:
			best = mote
			best_dist = d
	return best


func _capture(name: String) -> void:
	_pending_capture = name
	_capture_timer = 0.2


func _demo_update(delta: float) -> void:
	_stage_timer += delta
	demo_label.text = "DEMO stage %d  absorbed=%d hits=%d retries=%d" % [_stage, absorbed, hits, retries]
	if _stage_timer > DEMO_TIMEOUT:
		print("[M2] demo stage ", _stage, " timed out")
		_finish_demo()
		return
	match _stage:
		0:
			var mote := _nearest_mote()
			if mote == null:
				_finish_demo()
				return
			var to_mote := mote.global_position - player.global_position
			player.demo_dir = to_mote.normalized() if to_mote.length() > 40.0 else Vector2.ZERO
			player.demo_interact_held = to_mote.length() <= PlayerController.ABSORB_RANGE - 5.0
			if absorbed > 0:
				player.demo_interact_held = false
				player.demo_dir = Vector2.ZERO
				_capture("absorb")
				_stage = 1
				_stage_timer = 0.0
		1:
			var to_pred := predator.global_position - player.global_position
			player.demo_dir = to_pred.normalized() if to_pred.length() > 30.0 else Vector2.ZERO
			if hits > 0:
				player.demo_dir = Vector2.ZERO
				_capture("hit")
				_stage = 2
				_stage_timer = 0.0
		2:
			# Stand still and let the predator finish it; invulnerability
			# spaces the hits so this also exercises the window.
			player.demo_dir = Vector2.ZERO
			if player.dead:
				_capture("retry")
				_stage = 3
				_stage_timer = 0.0
		3:
			if _stage_timer > 0.3:
				_retry()
				_stage = 4
				_stage_timer = 0.0
		4:
			if _pending_capture == "" and _stage_timer > 0.2:
				_finish_demo()


## Turns the run's observations into failed criteria; empty means PASS.
## Separate from the run so it can be regression-tested (tests/m2_verdict_check.gd).
func evaluate_demo(absorbed_count: int, hit_count: int, retry_count: int, shots: int,
		min_pos: Vector2, max_pos: Vector2, revived: bool) -> Array[String]:
	var failures: Array[String] = []
	if absorbed_count < 1:
		failures.append("absorption: no mote was absorbed")
	if hit_count < 1:
		failures.append("damage: the predator never landed a hit")
	if retry_count < 1 or not revived:
		failures.append("retry: no respawn happened after defeat")
	if shots != DEMO_SHOTS:
		failures.append("captures: %d of %d screenshots saved" % [shots, DEMO_SHOTS])
	if not (min_pos.x >= DEMO_BOUNDS.position.x and max_pos.x <= DEMO_BOUNDS.end.x
			and min_pos.y >= DEMO_BOUNDS.position.y and max_pos.y <= DEMO_BOUNDS.end.y):
		failures.append("bounds: left the room (x %s..%s, y %s..%s)" % [min_pos.x, max_pos.x, min_pos.y, max_pos.y])
	return failures


func _finish_demo() -> void:
	_done = true
	print("[M2] DEMO DONE")
	print("[M2] absorbed=", absorbed, " hits=", hits, " retries=", retries)
	print("[M2] captures: ", _captured)
	print("[M2] position range x [", _min_pos.x, ", ", _max_pos.x, "] y [", _min_pos.y, ", ", _max_pos.y, "]")
	var failures := evaluate_demo(absorbed, hits, retries, _captured.size(),
		_min_pos, _max_pos, not player.dead)
	for failure in failures:
		print("[M2] FAILED: ", failure)
	print("[M2] DEMO RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)


## M3 demo: feed to the evolution cost, evolve at the alcove, kill the predator.
func _m3_demo_update(delta: float) -> void:
	_stage_timer += delta
	demo_label.text = "DEMO stage %d  nutrition=%.0f evolved=%s killed=%s" % [
		_stage, player.nutrition, player.evolved, predator_defeated]
	if _stage_timer > DEMO_TIMEOUT:
		print("[M3] demo stage ", _stage, " timed out")
		_finish_m3_demo()
		return
	match _stage:
		0:
			var mote := _nearest_mote()
			if player.nutrition >= player.EVOLVE_COST or mote == null:
				player.demo_interact_held = false
				player.demo_dir = Vector2.ZERO
				_stage = 1
				_stage_timer = 0.0
				return
			var to_mote := mote.global_position - player.global_position
			player.demo_dir = to_mote.normalized() if to_mote.length() > 40.0 else Vector2.ZERO
			player.demo_interact_held = to_mote.length() <= PlayerController.ABSORB_RANGE - 5.0
		1:
			var to_zone := zone.global_position - player.global_position
			player.demo_dir = to_zone.normalized() if to_zone.length() > 20.0 else Vector2.ZERO
			if zone.in_range(player.global_position):
				player.demo_dir = Vector2.ZERO
				if _pending_capture == "":
					if not _captured.has("requirement") and _stage_timer > 0.4:
						_capture("requirement")
					elif _captured.has("requirement") and _stage_timer > 0.9 and _try_evolve():
						_stage = 2
						_stage_timer = 0.0
		2:
			player.demo_dir = Vector2.ZERO
			if _pending_capture == "":
				if not _captured.has("evolve") and _stage_timer > 0.35:
					_capture("evolve")
				elif _captured.has("evolve") and _stage_timer > 0.7:
					_stage = 3
					_stage_timer = 0.0
		3:
			if player.dead:
				# Dying to the predator is legitimate gameplay; the demo recovers
				# the way a player does instead of failing the run.
				_retry()
				_stage_timer = 0.0
				return
			# The burst effect lives for a third of a second, so grab it as soon
			# as one fires rather than after the fight is over.
			if _pending_capture == "" and _bursts > 0 and not _captured.has("burst"):
				_capture("burst")
				return
			if predator_defeated or predator == null:
				player.demo_dir = Vector2.ZERO
				player.demo_attack_pressed = false
				if _pending_capture == "":
					if not _captured.has("kill"):
						_capture("kill")
					elif _stage_timer > 0.6:
						_stage = 4
						_stage_timer = 0.0
				return
			var to_pred := predator.global_position - player.global_position
			var d := to_pred.length()
			# Orbit the target rather than charging it: on a tangent the closing
			# speed is zero, so the faster player keeps its distance while the
			# ring still reaches. Biased toward the middle so the run cannot be
			# pinned against a wall.
			var tangent := Vector2(-to_pred.y, to_pred.x).normalized()
			if tangent.dot(ROOM.get_center() - player.global_position) < 0.0:
				tangent = -tangent
			if player.can_attack() and d >= 85.0 and d <= PlayerController.BURST_RANGE - 10.0:
				player.demo_attack_pressed = true
			if d > PlayerController.BURST_RANGE - 20.0:
				player.demo_dir = (to_pred.normalized() + tangent * 0.5).normalized()
			elif d < 90.0:
				player.demo_dir = (-to_pred.normalized() + tangent * 0.7).normalized()
			else:
				player.demo_dir = tangent
		4:
			if _pending_capture == "" and _stage_timer > 0.3:
				_finish_m3_demo()


func evaluate_m3_demo(did_evolve: bool, did_kill: bool, shots: Array, nutrition_left: float,
		min_pos: Vector2, max_pos: Vector2) -> Array[String]:
	var failures: Array[String] = []
	if not did_evolve:
		failures.append("evolution: the body never evolved")
	if not did_kill:
		failures.append("hunt: the burst never defeated the predator")
	if nutrition_left < KILL_REWARD:
		failures.append("economy: nutrition %.0f is below the kill reward %.0f (cost not paid?)" % [nutrition_left, KILL_REWARD])
	for shot in M3_SHOTS:
		if not shots.has(shot):
			failures.append("captures: missing the \"%s\" screenshot (saved %s)" % [shot, shots])
	if not (min_pos.x >= DEMO_BOUNDS.position.x and max_pos.x <= DEMO_BOUNDS.end.x
			and min_pos.y >= DEMO_BOUNDS.position.y and max_pos.y <= DEMO_BOUNDS.end.y):
		failures.append("bounds: left the room (x %s..%s, y %s..%s)" % [min_pos.x, max_pos.x, min_pos.y, max_pos.y])
	return failures


func _finish_m3_demo() -> void:
	_done = true
	print("[M3] DEMO DONE")
	print("[M3] evolved=", player.evolved, " killed=", predator_defeated, " nutrition=", player.nutrition)
	print("[M3] captures: ", _captured)
	print("[M3] position range x [", _min_pos.x, ", ", _max_pos.x, "] y [", _min_pos.y, ", ", _max_pos.y, "]")
	var failures := evaluate_m3_demo(player.evolved, predator_defeated, _captured,
		player.nutrition, _min_pos, _max_pos)
	for failure in failures:
		print("[M3] FAILED: ", failure)
	print("[M3] DEMO RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)


func _save_capture(name: String) -> void:
	var prefix := "M3" if m3_demo else "M2"
	var path := outdir + "/" + prefix + "_prototype-" + name + "_v01.png"
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		push_error("[%s] SCREENSHOT failed: no viewport image (headless run?)" % prefix)
		return
	var err: Error = img.save_png(path)
	if err != OK:
		push_error("[%s] SCREENSHOT failed: %s (%d)" % [prefix, path, err])
	else:
		_captured.append(name)
		print("[%s] SCREENSHOT saved: %s" % [prefix, path])
