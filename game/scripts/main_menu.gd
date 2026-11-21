class_name MainMenu
extends Node2D
## Procedural main menu — the player-facing entry point (Phase 3/4).
##
## Three views shown one at a time: TITLE -> MAIN -> MAP_SELECT. All UI is built
## from Labels/Panels with the same translucent dark frame + accent convention
## as the gameplay HUDs. No art, audio or font assets are used or implied.
##
## Input comes only from the central InputMap actions: move_up, move_down,
## interact, attack, pause. Public on_* methods mirror those actions so the
## headless regression check can drive the exact same code path.
##
## Run: godot --headless --audio-driver Dummy --path game \
##   res://scenes/main_menu.tscn --quit-after 5
## Prints [MENU] READY on load.

const PANEL_TITLE := "TITLE"
const PANEL_MAIN := "MAIN"
const PANEL_MAP_SELECT := "MAP_SELECT"
const PANELS: Array[String] = [PANEL_TITLE, PANEL_MAIN, PANEL_MAP_SELECT]

const MAIN_ENTRIES: Array[String] = ["New Game", "Continue", "Map Select", "Quit"]

## Honest status markers: "code exists", "placeholder", "proposed placeholder".
## Never "Approved" or "final" — no art/design direction is approved here.
## map01 is run through the JSON-driven map_runner.tscn; there is no map01.tscn.
const MAP_ENTRIES: Array[Dictionary] = [
	{"name": "Region Slice", "path": "res://scenes/region_slice.tscn", "status": "code exists"},
	{"name": "map01", "path": "res://scenes/map_runner.tscn", "status": "code exists"},
	{"name": "map02", "path": "res://scenes/map02.tscn", "status": "proposed placeholder"},
	{"name": "map03", "path": "res://scenes/map03.tscn", "status": "code exists"},
	{"name": "map04", "path": "res://scenes/map04.tscn", "status": "proposed placeholder"},
	{"name": "map05", "path": "res://scenes/map05.tscn", "status": "proposed placeholder"},
	{"name": "map06", "path": "res://scenes/map06.tscn", "status": "proposed placeholder"},
	{"name": "map07", "path": "res://scenes/map07.tscn", "status": "proposed placeholder"},
	{"name": "map08", "path": "res://scenes/map08.tscn", "status": "proposed placeholder"},
]

const ALLOWED_STATUS := ["code exists", "placeholder", "proposed placeholder"]

const BG := Color(0.05, 0.16, 0.18)
const GOLD := Color(0.95, 0.76, 0.31)
const TEAL_LIGHT := Color(0.56, 0.96, 0.89)
const CORAL := Color(0.95, 0.48, 0.42)
const DIM := Color(0.78, 0.82, 0.80)

# Public state (observed by the headless check).
var panel: String = PANEL_TITLE
var selection: int = 0
var confirming_new_game: bool = false
var no_progress_shown: bool = false
var last_scene_request: String = ""
var quit_requested: bool = false

# Test seams: real gameplay keeps both true. The headless check disables them
# so it can observe requests without changing scene or killing the test runner.
var change_scene_on_request: bool = true
var quit_on_request: bool = true
var save_path: String = SaveState.DEFAULT_PATH

var _title_panel: Panel
var _main_panel: Panel
var _map_panel: Panel
var _main_labels: Array[Label] = []
var _map_labels: Array[Label] = []
var _main_note: Label
var _map_note: Label


func _ready() -> void:
	_build_ui()
	_refresh()
	print("[MENU] READY")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_up"):
		on_move_up()
	elif event.is_action_pressed("move_down"):
		on_move_down()
	elif event.is_action_pressed("interact"):
		on_interact()
	elif event.is_action_pressed("attack") or event.is_action_pressed("pause"):
		on_back()


# ------------------------------------------------------------------ UI build

func _make_panel(rect: Rect2, accent: Color) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.075, 0.09, 0.86)
	style.border_color = Color(0.34, 0.72, 0.68, 0.42)
	style.set_border_width_all(1)
	style.border_width_left = 3
	style.border_color = accent
	style.set_corner_radius_all(12)
	p.add_theme_stylebox_override("panel", style)
	return p


func _make_label(text: String, font_size: int, color: Color, rect: Rect2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)

	# Title view.
	_title_panel = _make_panel(Rect2(180, 160, 600, 220), TEAL_LIGHT)
	ui.add_child(_title_panel)
	var title := _make_label("GENESIS — The Journey Before Life", 28, Color(0.98, 0.96, 0.93),
		Rect2(24, 36, 552, 48))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(title)
	var tagline := _make_label("(provisional tagline)", 17, GOLD, Rect2(24, 92, 552, 36))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(tagline)
	var prompt := _make_label("press interact (E / Space) to continue", 16, DIM,
		Rect2(24, 152, 552, 36))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(prompt)

	# Main view.
	_main_panel = _make_panel(Rect2(280, 110, 400, 320), CORAL)
	ui.add_child(_main_panel)
	var heading := _make_label("MAIN MENU", 24, Color(0.98, 0.96, 0.93),
		Rect2(24, 16, 352, 40))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(heading)
	for i in MAIN_ENTRIES.size():
		var row := _make_label(MAIN_ENTRIES[i], 22, DIM,
			Rect2(48, 72 + i * 40, 304, 36))
		_main_panel.add_child(row)
		_main_labels.append(row)
	_main_note = _make_label("", 15, GOLD, Rect2(24, 258, 352, 48))
	_main_panel.add_child(_main_note)

	# Map Select view.
	_map_panel = _make_panel(Rect2(230, 60, 500, 420), TEAL_LIGHT)
	ui.add_child(_map_panel)
	var map_heading := _make_label("MAP SELECT — proposed stages", 22,
		Color(0.98, 0.96, 0.93), Rect2(16, 10, 468, 36))
	map_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_panel.add_child(map_heading)
	for i in MAP_ENTRIES.size():
		var e: Dictionary = MAP_ENTRIES[i]
		var row := _make_label("%s  [%s]" % [e.get("name", ""), e.get("status", "")],
			17, DIM, Rect2(32, 54 + i * 32, 436, 30))
		_map_panel.add_child(row)
		_map_labels.append(row)
	_map_note = _make_label("", 14, GOLD, Rect2(16, 382, 468, 30))
	_map_panel.add_child(_map_note)


func _refresh() -> void:
	_title_panel.visible = panel == PANEL_TITLE
	_main_panel.visible = panel == PANEL_MAIN
	_map_panel.visible = panel == PANEL_MAP_SELECT

	for i in _main_labels.size():
		var selected: bool = i == selection
		_main_labels[i].text = ("› " if selected else "  ") + MAIN_ENTRIES[i]
		_main_labels[i].add_theme_color_override("font_color",
			GOLD if selected else DIM)
	if confirming_new_game:
		_main_note.text = "Erase progress? interact again"
	elif no_progress_shown:
		_main_note.text = "No progress to continue."
	else:
		_main_note.text = "W/S — move  •  E — select  •  J / Esc — back"

	for i in _map_labels.size():
		var e: Dictionary = MAP_ENTRIES[i]
		var selected: bool = i == selection
		_map_labels[i].text = ("› " if selected else "  ") + "%s  [%s]" % [
			e.get("name", ""), e.get("status", "")]
		_map_labels[i].add_theme_color_override("font_color",
			GOLD if selected else DIM)
	_map_note.text = "E — start  •  J / Esc — back"


# ------------------------------------------------------------------- actions

func _show(next: String) -> void:
	if not PANELS.has(next):
		return
	panel = next
	selection = 0
	confirming_new_game = false
	no_progress_shown = false
	_refresh()


func _entry_count() -> int:
	return MAIN_ENTRIES.size() if panel == PANEL_MAIN else MAP_ENTRIES.size()


func on_move_up() -> void:
	if panel == PANEL_TITLE:
		return
	selection = wrapi(selection - 1, 0, _entry_count())
	_refresh()


func on_move_down() -> void:
	if panel == PANEL_TITLE:
		return
	selection = wrapi(selection + 1, 0, _entry_count())
	_refresh()


func on_interact() -> void:
	match panel:
		PANEL_TITLE:
			_show(PANEL_MAIN)
		PANEL_MAIN:
			_activate_main()
		PANEL_MAP_SELECT:
			_activate_map_select()


func on_back() -> void:
	if confirming_new_game:
		# Cancelling the destructive confirmation keeps the selection and save.
		confirming_new_game = false
		_refresh()
		return
	match panel:
		PANEL_MAIN:
			_show(PANEL_TITLE)
		PANEL_MAP_SELECT:
			_show(PANEL_MAIN)


func _activate_main() -> void:
	match selection:
		0: # New Game — destructive, requires two-step confirmation.
			if confirming_new_game:
				SaveState.clear(save_path)
				confirming_new_game = false
				_show(PANEL_MAP_SELECT)
			else:
				confirming_new_game = true
				_refresh()
		1: # Continue.
			if SaveState.read(save_path).is_empty():
				no_progress_shown = true
				_refresh()
			else:
				_request_scene("res://scenes/region_slice.tscn")
		2: # Map Select.
			_show(PANEL_MAP_SELECT)
		3: # Quit.
			quit_requested = true
			if quit_on_request:
				get_tree().quit()


func _activate_map_select() -> void:
	if selection >= 0 and selection < MAP_ENTRIES.size():
		_request_scene(str(MAP_ENTRIES[selection].get("path", "")))


func _request_scene(path: String) -> void:
	last_scene_request = path
	if change_scene_on_request and get_tree() != null:
		get_tree().change_scene_to_file(path)


# --------------------------------------------------------------- pure verdict

## Pure rule evaluator: one named failure per broken rule (empty = PASS).
## Only keys present in `facts` are checked, matching evaluate_slice_run().
func evaluate_menu(facts: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if facts.has("panel") and not PANELS.has(str(facts["panel"])):
		failures.append("panel: unknown panel '%s'" % str(facts["panel"]))
	if facts.has("selection") and facts.has("entry_count"):
		var s := int(facts["selection"])
		var n := int(facts["entry_count"])
		if n <= 0 or s < 0 or s >= n:
			failures.append("selection: index %d out of range for %d entries" % [s, n])
	if facts.has("map_count") and int(facts["map_count"]) != MAP_ENTRIES.size():
		failures.append("map-count: expected %d entries, got %d" % [
			MAP_ENTRIES.size(), int(facts["map_count"])])
	if facts.has("entry") and not _is_known_entry(str(facts["entry"])):
		failures.append("entry: unknown map entry '%s'" % str(facts["entry"]))
	if facts.has("path") and not _is_known_path(str(facts["path"])):
		failures.append("path: unregistered scene path '%s'" % str(facts["path"]))
	if facts.has("status") and not ALLOWED_STATUS.has(str(facts["status"])):
		failures.append("status: dishonest status '%s'" % str(facts["status"]))
	if facts.has("label_text"):
		var line := str(facts["label_text"])
		if line.contains("Approved") or line.contains("final"):
			failures.append("status: a stage label must not say Approved or final")
	if facts.has("confirming") and bool(facts["confirming"]) \
			and facts.has("panel") and str(facts["panel"]) != PANEL_MAIN:
		failures.append("confirm: New Game confirmation is only valid on MAIN")
	if facts.has("save_cleared_before_confirm") and bool(facts["save_cleared_before_confirm"]):
		failures.append("confirm: save must not be cleared before the second interact")
	if facts.has("continue_without_save") and bool(facts["continue_without_save"]):
		failures.append("continue: no progress must not start a run")
	return failures


func _is_known_entry(name: String) -> bool:
	for e in MAP_ENTRIES:
		if str(e.get("name", "")) == name:
			return true
	return false


func _is_known_path(path: String) -> bool:
	for e in MAP_ENTRIES:
		if str(e.get("path", "")) == path:
			return true
	return path == "res://scenes/region_slice.tscn"
