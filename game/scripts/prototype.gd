extends Node2D
## Milestone 2 — absorption & survival prototype.
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
const DEMO_SHOTS := 3
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
var motes: Array[Absorbable] = []

var health_label: Label
var nutrition_label: Label
var state_label: Label
var retry_label: Label
var demo_label: Label
var pause_label: Label

# Observed run facts (HUD + demo verdict).
var absorbed := 0
var hits := 0
var retries := 0

var _paused := false
var _flash := 0.0
var _anim := 0.0

# Demo mode.
var demo := false
var outdir := ""
var _stage := 0
var _stage_timer := 0.0
var _pending_capture := ""
var _capture_timer := 0.0
var _captured: Array[String] = []
var _min_pos := Vector2.INF
var _max_pos := Vector2(-INF, -INF)
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[M2] READY prototype, viewport ", get_viewport_rect().size)
	_build_background()
	_build_room()
	_build_player()
	_build_motes()
	_build_predator()
	_build_camera()
	_build_hud()
	for a in OS.get_cmdline_user_args():
		if a == "--m2-demo":
			demo = true
		elif a.begins_with("--outdir="):
			outdir = a.trim_prefix("--outdir=")
	if demo:
		player.demo_active = true
		print("[M2] demo mode, outdir=", outdir)


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
		pass # interact belongs to absorption while alive
	if player.dead and not demo and Input.is_action_just_pressed("interact"):
		_retry()
	if demo and not _done:
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
	player.position = START_POS
	add_child(player)
	player.nutrition_gained.connect(_on_nutrition)
	player.damaged.connect(_on_damaged)
	player.died.connect(_on_died)


func _build_motes() -> void:
	for i in MOTE_START.size():
		var mote := Absorbable.new()
		mote.position = MOTE_START[i]
		mote.drift_speed = 0.6 + 0.15 * i
		add_child(mote)
		motes.append(mote)


func _build_predator() -> void:
	predator = Predator.new()
	predator.position = PREDATOR_START
	predator.patrol_min_x = 1000.0
	predator.patrol_max_x = 1520.0
	predator.player = player
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


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	var title := _make_label("GENESIS — M2 Prototype: Absorption & Survival", 22, Color(0.95, 0.97, 0.95))
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
	demo_label = _make_label("", 16, GOLD)
	demo_label.offset_top = 104
	demo_label.offset_bottom = 128
	demo_label.visible = demo
	ui.add_child(demo_label)
	var hint := _make_label(
		"WASD — swim  •  hold E near a mote — absorb  •  Shift — grip  •  Esc — pause",
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


func _save_capture(name: String) -> void:
	var path := outdir + "/M2_prototype-" + name + "_v01.png"
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		push_error("[M2] SCREENSHOT failed: no viewport image (headless run?)")
		return
	var err: Error = img.save_png(path)
	if err != OK:
		push_error("[M2] SCREENSHOT failed: %s (%d)" % [path, err])
	else:
		_captured.append(name)
		print("[M2] SCREENSHOT saved: ", path)
