extends Node2D
## Milestone 0 test scene.
##
## Proves three things:
##   1. The project launches into a scene without errors.
##   2. Viewport scaling works: gold corner markers, edge ticks and a
##      border frame are anchored to the viewport edges, so a screenshot
##      at any window size shows whether the layout scales.
##   3. Centralised input actions fire: the readout shows the last action
##      pressed and which actions are currently held.
##
## Run with `-- --screenshot=<path>` to save a PNG of the running scene
## after a short settle delay and quit (used for scaling verification).
## In screenshot mode the scene simulates one "interact" + "move_right"
## press through the real input system, so the readout proves the
## InputMap actions exist and fire.

const ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"interact", "pause",
]

const GOLD := Color(0.95, 0.76, 0.31)
const TEAL_LIGHT := Color(0.56, 0.96, 0.89)
const BG := Color(0.05, 0.16, 0.18)

var _last_action: String = "(none yet)"
var _paused: bool = false
var _frame: int = 0
var _screenshot_path: String = ""
var _simulated: bool = false

var _resolution_label: Label
var _input_label: Label
var _pause_label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			_screenshot_path = arg.trim_prefix("--screenshot=")
	print("[M0] READY test scene, viewport ", get_viewport_rect().size)
	for action in ACTIONS:
		print("[M0] INPUT ", action, ": ", InputMap.action_get_events(action).size(), " events")
	_build_ui()


func _input(event: InputEvent) -> void:
	for action in ACTIONS:
		if event.is_action_pressed(action):
			_last_action = action
			if action == "pause":
				_paused = not _paused
				_pause_label.visible = _paused
			_update_input_label()


func _process(_delta: float) -> void:
	_frame += 1
	_resolution_label.text = "Viewport: %s  |  Window: %s" % [
		get_viewport_rect().size, DisplayServer.window_get_size()
	]
	_update_input_label()
	if _screenshot_path != "":
		if _frame == 10 and not _simulated:
			# Feed real key events through the input system (parse_input_event
			# triggers _input; Input.action_press would not).
			_simulate_key(KEY_D, true)
			_simulate_key(KEY_E, true)
			_simulated = true
		elif _frame == 20 and _simulated:
			_simulate_key(KEY_D, false)
			_simulate_key(KEY_E, false)
		elif _frame >= 40:
			var img: Image = get_viewport().get_texture().get_image()
			var err: Error = img.save_png(_screenshot_path)
			if err == OK:
				print("[M0] SCREENSHOT saved: ", _screenshot_path)
			else:
				push_error("[M0] SCREENSHOT failed: %s (%s)" % [_screenshot_path, err])
			get_tree().quit()


func _simulate_key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _update_input_label() -> void:
	var held: Array[String] = []
	for action in ACTIONS:
		if Input.is_action_pressed(action):
			held.append(action)
	var held_text: String = ", ".join(held) if held.size() > 0 else "(none)"
	_input_label.text = "Last action: %s  |  Held: %s" % [_last_action, held_text]


func _build_ui() -> void:
	var ui: CanvasLayer = $UI

	# Background.
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(bg)

	# Border frame hugging the viewport edges (2 px).
	_add_edge_rect(ui, 0.0, 0.0, 1.0, 0.0, 0, 0, 0, 2) # top
	_add_edge_rect(ui, 0.0, 1.0, 1.0, 1.0, 0, -2, 0, 0) # bottom
	_add_edge_rect(ui, 0.0, 0.0, 0.0, 1.0, 0, 0, 2, 0) # left
	_add_edge_rect(ui, 1.0, 0.0, 1.0, 1.0, -2, 0, 0, 0) # right

	# Gold corner markers, 24x24, 8 px in from each corner.
	_add_rect(ui, GOLD, 0.0, 0.0, 0.0, 0.0, 8, 8, 32, 32)
	_add_rect(ui, GOLD, 1.0, 0.0, 1.0, 0.0, -32, 8, -8, 32)
	_add_rect(ui, GOLD, 0.0, 1.0, 0.0, 1.0, 8, -32, 32, -8)
	_add_rect(ui, GOLD, 1.0, 1.0, 1.0, 1.0, -32, -32, -8, -8)

	# Edge-centre ticks (teal), 24x8 / 8x24.
	_add_rect(ui, TEAL_LIGHT, 0.5, 0.0, 0.5, 0.0, -12, 8, 12, 16)
	_add_rect(ui, TEAL_LIGHT, 0.5, 1.0, 0.5, 1.0, -12, -16, 12, -8)
	_add_rect(ui, TEAL_LIGHT, 0.0, 0.5, 0.0, 0.5, 8, -12, 16, 12)
	_add_rect(ui, TEAL_LIGHT, 1.0, 0.5, 1.0, 0.5, -16, -12, -8, 12)

	# Centre crosshair dot.
	_add_rect(ui, GOLD, 0.5, 0.5, 0.5, 0.5, -4, -4, 4, 4)

	# Title.
	var title := _make_label("GENESIS — Milestone 0 Test Scene", 28, Color(0.95, 0.97, 0.95))
	title.anchor_top = 0.28
	title.anchor_bottom = 0.28
	title.offset_top = -20
	title.offset_bottom = 20
	ui.add_child(title)

	# Live resolution readout.
	_resolution_label = _make_label("", 18, Color(0.75, 0.9, 0.88))
	_resolution_label.anchor_top = 0.38
	_resolution_label.anchor_bottom = 0.38
	_resolution_label.offset_top = -14
	_resolution_label.offset_bottom = 14
	ui.add_child(_resolution_label)

	# Input debug readout.
	_input_label = _make_label("Last action: (none yet)  |  Held: (none)", 18, TEAL_LIGHT)
	_input_label.anchor_top = 0.62
	_input_label.anchor_bottom = 0.62
	_input_label.offset_top = -14
	_input_label.offset_bottom = 14
	ui.add_child(_input_label)

	# Controls hint, pinned to the bottom.
	var hint := _make_label("WASD / Arrows — move   •   E / Space — interact   •   Esc / P — pause", 16, Color(0.65, 0.8, 0.78))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -48
	hint.offset_bottom = -16
	ui.add_child(hint)

	# Pause overlay label, hidden until the pause action fires.
	_pause_label = _make_label("PAUSED — press Esc / P to resume", 32, GOLD)
	_pause_label.anchor_top = 0.5
	_pause_label.anchor_bottom = 0.5
	_pause_label.offset_top = -24
	_pause_label.offset_bottom = 24
	_pause_label.visible = false
	ui.add_child(_pause_label)


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


func _add_rect(parent: Node, color: Color, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.anchor_left = al
	rect.anchor_top = at
	rect.anchor_right = ar
	rect.anchor_bottom = ab
	rect.offset_left = ol
	rect.offset_top = ot
	rect.offset_right = orr
	rect.offset_bottom = ob
	parent.add_child(rect)
	return rect


func _add_edge_rect(parent: Node, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> ColorRect:
	return _add_rect(parent, Color(0.35, 0.65, 0.62, 0.8), al, at, ar, ab, ol, ot, orr, ob)
