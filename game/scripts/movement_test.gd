extends Node2D
## Milestone 1 — movement test room (Membrane Caverns).
##
## A bounded biological room (1920x1080, two screens wide) with a floor,
## ceiling, walls, one floating platform and one vertical pillar, a
## smoothed following camera, and a HUD that shows the player's state.
##
## Play:   godot --path game res://scenes/movement_test.tscn
## Smoke:  godot --headless --path game res://scenes/movement_test.tscn --quit-after 5
## Demo:   xvfb-run -a -s "-screen 0 960x540x24" godot --path game \
##           res://scenes/movement_test.tscn -- --m1-demo --outdir=/abs/out
## The demo autopilots through the same movement code (swim -> crawl ->
## grip -> detach -> camera) and saves 4 screenshots, then quits.

const ROOM := Rect2(0, 0, 1920, 1080)
const FLOOR_TOP := 1020.0
const START_POS := Vector2(300, 500)
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const DEMO_SHOTS := 4
const DEMO_MIN_CAMERA_DX := 600.0

const BG := Color(0.05, 0.16, 0.18)
const SLAB := Color(0.10, 0.32, 0.30)
const SLAB_EDGE := Color(0.56, 0.96, 0.89)
const GOLD := Color(0.95, 0.76, 0.31)
const TEAL_LIGHT := Color(0.56, 0.96, 0.89)

var player: PlayerController
var camera: Camera2D
var state_label: Label
var readout_label: Label
var demo_label: Label
var pause_label: Label

var _paused := false
var _anim_time := 0.0
var _blobs: Array = []
var _motes: Array = []

# Demo mode.
var demo := false
var outdir := "/tmp/m1"
var _stage := 0
var _stage_timer := 0.0
var _pending_capture := ""
var _capture_timer := 0.0
var _captured: Array[String] = []
var _min_pos := Vector2.INF
var _max_pos := Vector2(-INF, -INF)
var _cam_start_x := 0.0
var _done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[M1] READY movement test, viewport ", get_viewport_rect().size)
	for action in ["move_left", "move_right", "move_up", "move_down", "interact", "pause", "grip"]:
		print("[M1] INPUT ", action, ": ", InputMap.action_get_events(action).size(), " events")
	_build_background()
	_build_room()
	_build_player()
	_build_camera()
	_build_hud()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--m1-demo":
			demo = true
		elif a.begins_with("--outdir="):
			outdir = a.trim_prefix("--outdir=")
	if demo:
		player.demo_active = true
		_cam_start_x = camera.global_position.x
		print("[M1] demo mode, outdir=", outdir)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_paused = not _paused
		get_tree().paused = _paused
		pause_label.visible = _paused
		print("[M1] paused=", _paused)


func _process(delta: float) -> void:
	_anim_time += delta
	_animate_ambient(delta)
	if _paused:
		return
	if player != null:
		_min_pos = _min_pos.min(player.global_position)
		_max_pos = _max_pos.max(player.global_position)
		camera.global_position = player.global_position
		_update_hud()
	if demo and not _done:
		_demo_update(delta)
	if _pending_capture != "":
		_capture_timer -= delta
		if _capture_timer <= 0.0:
			_save_capture(_pending_capture)
			_pending_capture = ""


# ------------------------------------------------------------------ build

func _radial_texture(size: int, stops: Array, from: Vector2, to: Vector2) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, stops[0][1])
	grad.set_color(1, stops[stops.size() - 1][1])
	for i in range(1, stops.size() - 1):
		grad.add_point(stops[i][0], stops[i][1])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = size
	gt.height = size
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = from
	gt.fill_to = to
	return gt


func _build_background() -> void:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -2
	add_child(backdrop)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(bg)
	# Soft membrane blobs drifting in world space.
	var blob_tex: GradientTexture2D = _radial_texture(256, [
		[0.0, Color(0.16, 0.42, 0.38, 0.55)],
		[1.0, Color(0.16, 0.42, 0.38, 0.0)],
	], Vector2(0.5, 0.5), Vector2(0.5, 1.0))
	for def in [
		[Vector2(500, 300), 2.2], [Vector2(1200, 250), 2.8],
		[Vector2(1600, 700), 2.4], [Vector2(250, 850), 2.0],
		[Vector2(950, 500), 1.6],
	]:
		var s := Sprite2D.new()
		s.texture = blob_tex
		s.position = def[0]
		s.scale = Vector2(def[1], def[1])
		s.set_meta("base", def[0])
		add_child(s)
		_blobs.append(s)
	# Amber nutrient stream along the floor.
	var stream := ColorRect.new()
	stream.color = Color(0.85, 0.62, 0.18, 0.35)
	stream.position = Vector2(60, FLOOR_TOP - 14)
	stream.size = Vector2(1800, 14)
	add_child(stream)
	var mote_tex: GradientTexture2D = _radial_texture(32, [
		[0.0, Color(1.0, 0.85, 0.42, 0.9)],
		[1.0, Color(1.0, 0.85, 0.42, 0.0)],
	], Vector2(0.5, 0.5), Vector2(0.5, 1.0))
	for i in 24:
		var m := Sprite2D.new()
		m.texture = mote_tex
		m.position = Vector2(randf_range(80, 1840), FLOOR_TOP - randf_range(4, 24))
		m.scale = Vector2(0.35, 0.35)
		m.set_meta("speed", randf_range(12.0, 30.0))
		add_child(m)
		_motes.append(m)


func _build_room() -> void:
	RoomBuilder.build_room(self, ROOM, FLOOR_TOP, [])


func _build_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.position = START_POS
	add_child(player)


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


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	var title := _make_label("GENESIS — Milestone 1 Movement Test", 22, Color(0.95, 0.97, 0.95))
	title.anchor_top = 0.0
	title.offset_top = 12
	title.offset_bottom = 44
	ui.add_child(title)
	state_label = _make_label("State: SWIM", 20, GOLD)
	state_label.anchor_top = 0.0
	state_label.offset_top = 48
	state_label.offset_bottom = 76
	ui.add_child(state_label)
	readout_label = _make_label("", 16, TEAL_LIGHT)
	readout_label.anchor_top = 0.0
	readout_label.offset_top = 78
	readout_label.offset_bottom = 102
	ui.add_child(readout_label)
	demo_label = _make_label("", 16, Color(0.95, 0.76, 0.31))
	demo_label.anchor_top = 0.0
	demo_label.offset_top = 104
	demo_label.offset_bottom = 128
	demo_label.visible = demo
	ui.add_child(demo_label)
	var hint := _make_label("WASD / Arrows — swim  •  Shift — grip  •  move on the floor — crawl  •  Esc / P — pause", 15, Color(0.65, 0.8, 0.78))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -36
	hint.offset_bottom = -12
	ui.add_child(hint)
	pause_label = _make_label("PAUSED — press Esc / P to resume", 32, GOLD)
	pause_label.anchor_top = 0.5
	pause_label.anchor_bottom = 0.5
	pause_label.offset_top = -24
	pause_label.offset_bottom = 24
	pause_label.visible = false
	ui.add_child(pause_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.offset_left = 0
	label.offset_right = 0
	return label


func _update_hud() -> void:
	state_label.text = "State: " + player.state_name()
	readout_label.text = "Pos: (%d, %d)  Speed: %d px/s  Camera: (%d, %d)" % [
		player.global_position.x, player.global_position.y,
		player.velocity.length(), camera.global_position.x, camera.global_position.y,
	]


func _animate_ambient(_delta: float) -> void:
	for i in _blobs.size():
		var s: Sprite2D = _blobs[i]
		var base: Vector2 = s.get_meta("base")
		s.position = base + Vector2(
			sin(_anim_time * 0.11 + float(i) * 2.1) * 14.0,
			cos(_anim_time * 0.09 + float(i) * 1.3) * 10.0
		)
	for m in _motes:
		var mote: Sprite2D = m
		mote.position.x += float(mote.get_meta("speed")) * 0.016
		if mote.position.x > 1840.0:
			mote.position.x = 80.0


# ------------------------------------------------------------------ demo

func _steer(target: Vector2) -> Vector2:
	var d := target - player.global_position
	if d.length() < 30.0:
		return Vector2.ZERO
	return d.normalized()


func _demo_update(delta: float) -> void:
	_stage_timer += delta
	# Watchdog: no stage may take longer than 12 s; report and fail loudly
	# instead of hanging the run.
	if _stage_timer > 12.0:
		print("[M1] DEMO STUCK at stage ", _stage, " pos=", player.global_position, " state=", player.state_name())
		get_tree().quit(1)
		return
	# While a screenshot is pending, hold the current stage: advancing
	# would change the player's state before the capture fires (the
	# crawl/grip shots must show the state they claim, not the next one).
	if _pending_capture != "":
		return
	match _stage:
		0: # Settle at the start.
			player.demo_dir = Vector2.ZERO
			demo_label.text = "Demo: settle"
			if _stage_timer > 1.0:
				_stage = 1
				_stage_timer = 0.0
		1: # Swim right in open water; capture mid-swim.
			player.demo_dir = _steer(Vector2(700, 500))
			demo_label.text = "Demo: swim"
			if player.global_position.x >= 550.0 and player.state_name() == "SWIM":
				_schedule_capture("swim")
				_stage = 2
				_stage_timer = 0.0
		2: # Swim down to the floor, left of the platform (open water).
			player.demo_dir = _steer(Vector2(500, 960))
			demo_label.text = "Demo: descend to floor"
			if player.global_position.y >= 940.0:
				_stage = 3
				_stage_timer = 0.0
		3: # Crawl right along the floor; capture while crawling.
			player.demo_dir = _steer(Vector2(1050, 965))
			demo_label.text = "Demo: crawl"
			if player.state_name() == "CRAWL" and player.global_position.x >= 900.0:
				_schedule_capture("crawl")
				_stage = 4
				_stage_timer = 0.0
		4: # Swim up-left to below the platform.
			player.demo_dir = _steer(Vector2(950, 800))
			demo_label.text = "Demo: under the platform"
			if player.global_position.distance_to(Vector2(950, 800)) < 60.0:
				_stage = 5
				_stage_timer = 0.0
		5: # Rise until the head touches the platform underside, then grip.
			player.demo_dir = _steer(Vector2(950, 730))
			demo_label.text = "Demo: rise to underside"
			if player.is_on_ceiling():
				player.demo_grip_pressed = true
				_stage = 6
				_stage_timer = 0.0
		6: # Gripped: move right along the underside; capture while gripped.
			player.demo_dir = _steer(Vector2(1120, 735))
			demo_label.text = "Demo: grip"
			if player.state_name() == "GRIP" and player.global_position.x >= 1050.0:
				_schedule_capture("grip")
				_stage = 7
				_stage_timer = 0.0
			elif _stage_timer > 4.0 and player.state_name() != "GRIP":
				# Grip press missed the surface: rise again and retry once.
				print("[M1] demo: grip missed, retrying rise")
				_stage = 5
				_stage_timer = 0.0
		7: # Detach and pause briefly.
			player.demo_dir = Vector2.ZERO
			if _stage_timer < 0.4:
				if _stage_timer < 0.1:
					player.demo_grip_pressed = true
				demo_label.text = "Demo: detach"
			else:
				_stage = 8
				_stage_timer = 0.0
		8: # Swim to the far right; capture the camera having followed.
			player.demo_dir = _steer(Vector2(1700, 400))
			demo_label.text = "Demo: camera follow"
			if player.global_position.distance_to(Vector2(1700, 400)) < 70.0:
				_schedule_capture("camera")
				_stage = 9
				_stage_timer = 0.0
		9: # Wait for the last capture, then report and quit.
			player.demo_dir = Vector2.ZERO
			if _pending_capture == "" and _stage_timer > 0.5:
				_finish_demo()


func _schedule_capture(name: String) -> void:
	_pending_capture = name
	_capture_timer = 0.35


func _save_capture(name: String) -> void:
	var path := outdir + "/M1_movement-" + name + "_v01.png"
	var tex := get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		# Headless runs have no viewport image; fail loudly but keep the
		# verdict accurate (the missing capture is counted as a failure).
		push_error("[M1] SCREENSHOT failed: no viewport image (headless run?)")
		return
	var err: Error = img.save_png(path)
	if err == OK:
		print("[M1] SCREENSHOT saved: ", path)
		_captured.append(name)
	else:
		push_error("[M1] SCREENSHOT failed: %s (%s)" % [path, err])


func _finish_demo() -> void:
	_done = true
	print("[M1] DEMO DONE")
	print("[M1] state history: ", player.state_history())
	print("[M1] captures: ", _captured)
	print("[M1] position range x [", _min_pos.x, ", ", _max_pos.x, "] y [", _min_pos.y, ", ", _max_pos.y, "]")
	print("[M1] camera moved x: ", _cam_start_x, " -> ", camera.global_position.x)
	print("[M1] final state: ", player.state_name(), " at ", player.global_position)
	var camera_dx := camera.global_position.x - _cam_start_x
	var failures := evaluate_demo(player.state_history(), _min_pos, _max_pos, camera_dx, _captured.size())
	for failure in failures:
		print("[M1] FAILED: ", failure)
	print("[M1] DEMO RESULT: ", "PASS" if failures.is_empty() else "FAIL")
	# A demo run is evidence only if a failed criterion fails the process.
	get_tree().quit(0 if failures.is_empty() else 1)


## Turns the run's raw observations into the list of failed acceptance
## criteria; empty means PASS. Kept separate from the run itself so the
## verdict can be regression-tested headlessly (tests/demo_verdict_check.gd)
## — a verdict that cannot report a failure would let a broken demo exit 0.
func evaluate_demo(history: Array[String], min_pos: Vector2, max_pos: Vector2, camera_dx: float, shots: int) -> Array[String]:
	var failures: Array[String] = []
	if not (history.has("SWIM->CRAWL") and history.has("SWIM->GRIP")):
		failures.append("states: expected SWIM->CRAWL and SWIM->GRIP in %s" % [history])
	if not (min_pos.x >= 60.0 and max_pos.x <= 1860.0 and min_pos.y >= 60.0 and max_pos.y <= 1020.0):
		failures.append("bounds: left the room (x %s..%s, y %s..%s)" % [min_pos.x, max_pos.x, min_pos.y, max_pos.y])
	if not (camera_dx > DEMO_MIN_CAMERA_DX):
		failures.append("camera: followed only %d px (need > %d)" % [int(camera_dx), int(DEMO_MIN_CAMERA_DX)])
	if shots != DEMO_SHOTS:
		failures.append("captures: %d of %d screenshots saved" % [shots, DEMO_SHOTS])
	return failures
