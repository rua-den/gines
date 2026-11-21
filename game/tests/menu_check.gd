extends SceneTree
## Headless regression check: the procedural Main Menu flow.
##
## Contract (see main_menu.gd):
##   * A fresh menu is on TITLE with selection 0.
##   * interact on TITLE opens MAIN; move_up/move_down wrap on the entry lists.
##   * New Game needs two interact presses: the first only shows confirmation,
##     the second clears the save and opens MAP_SELECT. attack/pause cancels.
##   * Continue with no save stays on MAIN and reports a named failure.
##   * MAP_SELECT lists every stage with an honest status marker and routes each
##     entry to its real res://scenes/... path; attack/pause returns to MAIN.
##   * evaluate_menu(facts) is pure and returns one named failure per broken rule.
##
## Run:
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/menu_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

const EXPECTED_CASES := 12

# The brief's enumeration is authoritative: Region Slice + map01..map08 = 9
# entries ("10" was an orchestrator typo corrected in the ruling).
const EXPECTED_MAP_COUNT := 9

# Nine paths actually exist today: region_slice, the map01 JSON runner, and
# map02..map08. map01 routes to the JSON runner because no map01.tscn exists.
const EXPECTED_PATHS: Array[String] = [
	"res://scenes/region_slice.tscn",
	"res://scenes/map_runner.tscn",
	"res://scenes/map02.tscn",
	"res://scenes/map03.tscn",
	"res://scenes/map04.tscn",
	"res://scenes/map05.tscn",
	"res://scenes/map06.tscn",
	"res://scenes/map07.tscn",
	"res://scenes/map08.tscn",
]

const ALLOWED_STATUS := ["code exists", "placeholder", "proposed placeholder"]

const SAVE_PATH := "user://test_menu_save.cfg"

var _passed := 0
var _failed := 0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("[T] %s %-46s %s" % ["PASS" if ok else "FAIL", label, detail])


func _make_menu() -> MainMenu:
	SaveState.clear(SAVE_PATH)
	var menu: MainMenu = load("res://scenes/main_menu.tscn").instantiate()
	# Test seams: never change the real scene tree or quit the test runner.
	menu.change_scene_on_request = false
	menu.quit_on_request = false
	menu.save_path = SAVE_PATH
	get_root().add_child(menu)
	return menu


func _dispose(menu: MainMenu) -> void:
	SaveState.clear(SAVE_PATH)
	menu.free()
	await _frames(2)


func _case_fresh_is_title() -> void:
	var menu := _make_menu()
	await _frames(2)
	var ok: bool = menu.panel == "TITLE" and menu.selection == 0 \
		and not menu.confirming_new_game
	_check("fresh menu is on TITLE with selection 0", ok,
		"panel=%s selection=%d confirming=%s" % [menu.panel, menu.selection, menu.confirming_new_game])
	await _dispose(menu)


func _case_title_interact_opens_main() -> void:
	var menu := _make_menu()
	await _frames(2)
	menu.on_interact()
	var ok: bool = menu.panel == "MAIN" and menu.selection == 0
	_check("interact on TITLE opens MAIN", ok,
		"panel=%s selection=%d" % [menu.panel, menu.selection])
	await _dispose(menu)


func _case_navigation_wraps() -> void:
	var menu := _make_menu()
	await _frames(2)
	menu.on_interact() # MAIN
	menu.selection = menu.MAIN_ENTRIES.size() - 1
	menu.on_move_down()
	var wrapped_down: bool = menu.selection == 0
	menu.on_move_up()
	var wrapped_up: bool = menu.selection == menu.MAIN_ENTRIES.size() - 1
	_check("move_down/move_up wrap at MAIN ends", wrapped_down and wrapped_up,
		"after_down=%d after_up=%d count=%d" % [
			0 if wrapped_down else -1, menu.selection, menu.MAIN_ENTRIES.size()])
	await _dispose(menu)


func _case_new_game_first_interact_only_confirms() -> void:
	var menu := _make_menu()
	await _frames(2)
	SaveState.write(SAVE_PATH, {"evolved": true, "nutrition": 30.0})
	menu.on_interact() # MAIN
	menu.selection = 0 # New Game
	menu.on_interact() # first confirmation press
	var ok: bool = menu.confirming_new_game and menu.panel == "MAIN" \
		and not SaveState.read(SAVE_PATH).is_empty()
	_check("first New Game interact only confirms", ok,
		"confirming=%s panel=%s save=%s" % [
			menu.confirming_new_game, menu.panel, SaveState.read(SAVE_PATH)])
	await _dispose(menu)


func _case_new_game_second_interact_clears_and_routes() -> void:
	var menu := _make_menu()
	await _frames(2)
	SaveState.write(SAVE_PATH, {"evolved": true, "nutrition": 30.0})
	menu.on_interact() # MAIN
	menu.on_interact() # confirm
	menu.on_interact() # second press: clear + Map Select
	var ok: bool = not menu.confirming_new_game and menu.panel == "MAP_SELECT" \
		and SaveState.read(SAVE_PATH).is_empty()
	_check("second New Game interact clears + Map Select", ok,
		"confirming=%s panel=%s save_empty=%s" % [
			menu.confirming_new_game, menu.panel, SaveState.read(SAVE_PATH).is_empty()])
	await _dispose(menu)


func _case_attack_cancels_confirmation() -> void:
	var menu := _make_menu()
	await _frames(2)
	SaveState.write(SAVE_PATH, {"evolved": true, "nutrition": 30.0})
	menu.on_interact() # MAIN
	menu.on_interact() # confirm
	menu.on_back() # attack/pause cancels
	var ok: bool = not menu.confirming_new_game and menu.panel == "MAIN" \
		and not SaveState.read(SAVE_PATH).is_empty()
	_check("attack cancels New Game confirmation", ok,
		"confirming=%s panel=%s save=%s" % [
			menu.confirming_new_game, menu.panel, SaveState.read(SAVE_PATH)])
	await _dispose(menu)


func _case_continue_without_save_stays() -> void:
	var menu := _make_menu()
	await _frames(2)
	menu.on_interact() # MAIN
	menu.selection = 1 # Continue
	menu.on_interact()
	var failures := menu.evaluate_menu({"continue_without_save": menu.no_progress_shown})
	var named: bool = not failures.is_empty() and failures[0].begins_with("continue:")
	_check("Continue with no save stays on MAIN", menu.panel == "MAIN" and named,
		"panel=%s no_progress=%s failures=%s" % [
			menu.panel, menu.no_progress_shown, failures])
	await _dispose(menu)


func _case_map_select_entries_honest() -> void:
	var menu := _make_menu()
	await _frames(2)
	var entries: Array = menu.MAP_ENTRIES
	var count_ok: bool = entries.size() == EXPECTED_MAP_COUNT
	var status_ok := true
	var wording_ok := true
	for e in entries:
		if not ALLOWED_STATUS.has(str(e.get("status", ""))):
			status_ok = false
		var line: String = "%s %s" % [str(e.get("name", "")), str(e.get("status", ""))]
		if line.contains("Approved") or line.contains("final"):
			wording_ok = false
	_check("Map Select has 9 honest entries", count_ok and status_ok and wording_ok,
		"count=%d expected=%d status_ok=%s wording_ok=%s" % [
			entries.size(), EXPECTED_MAP_COUNT, status_ok, wording_ok])
	await _dispose(menu)


func _case_map_select_paths_correct() -> void:
	var menu := _make_menu()
	await _frames(2)
	var entries: Array = menu.MAP_ENTRIES
	var paths: Array[String] = []
	for e in entries:
		paths.append(str(e.get("path", "")))
	var all_known := true
	for p in paths:
		if not EXPECTED_PATHS.has(p) or not ResourceLoader.exists(p):
			all_known = false
	_check("all 9 map paths are correct and exist",
		paths.size() == EXPECTED_MAP_COUNT and all_known,
		"paths=%d known=%s" % [paths.size(), paths])
	await _dispose(menu)


func _case_selecting_entry_requests_scene() -> void:
	var menu := _make_menu()
	await _frames(2)
	menu.on_interact() # MAIN
	menu.selection = 2 # Map Select
	menu.on_interact()
	menu.selection = 0
	menu.on_interact()
	var first: String = menu.last_scene_request
	menu.selection = 1
	menu.on_interact()
	var second: String = menu.last_scene_request
	var ok: bool = first == "res://scenes/region_slice.tscn" \
		and second == "res://scenes/map_runner.tscn"
	_check("selecting an entry emits the scene request", ok,
		"first=%s second=%s" % [first, second])
	await _dispose(menu)


func _case_back_and_quit() -> void:
	var menu := _make_menu()
	await _frames(2)
	menu.on_interact() # MAIN
	menu.selection = 2 # Map Select
	menu.on_interact()
	menu.on_back() # attack/pause returns to MAIN
	var back_ok: bool = menu.panel == "MAIN"
	menu.selection = 3 # Quit
	menu.on_interact()
	var ok: bool = back_ok and menu.quit_requested
	_check("back returns to MAIN and Quit is callable", ok,
		"panel_after_back=%s quit_requested=%s" % ["MAIN" if back_ok else menu.panel, menu.quit_requested])
	await _dispose(menu)


func _case_negative_fixture() -> void:
	var menu := _make_menu()
	await _frames(2)
	var bad_panel := menu.evaluate_menu({"panel": "NO_SUCH_PANEL"})
	var bad_path := menu.evaluate_menu({"path": "res://scenes/not_a_map.tscn"})
	var bad_status := menu.evaluate_menu({"status": "Approved"})
	var ok: bool = not bad_panel.is_empty() and bad_panel[0].begins_with("panel:") \
		and not bad_path.is_empty() and bad_path[0].begins_with("path:") \
		and not bad_status.is_empty() and bad_status[0].begins_with("status:")
	_check("named negative fixture fails for the right reason", ok,
		"panel=%s path=%s status=%s" % [bad_panel, bad_path, bad_status])
	await _dispose(menu)


func _init() -> void:
	await _frames(2)
	await _case_fresh_is_title()
	await _case_title_interact_opens_main()
	await _case_navigation_wraps()
	await _case_new_game_first_interact_only_confirms()
	await _case_new_game_second_interact_clears_and_routes()
	await _case_attack_cancels_confirmation()
	await _case_continue_without_save_stays()
	await _case_map_select_entries_honest()
	await _case_map_select_paths_correct()
	await _case_selecting_entry_requests_scene()
	await _case_back_and_quit()
	await _case_negative_fixture()
	if _passed + _failed != EXPECTED_CASES:
		_failed += 1
		print("[T] FAIL only %d of %d cases reported" % [_passed + _failed, EXPECTED_CASES])
	print("[T] menu_check: ", "ALL PASS" if _failed == 0 else "%d FAILED" % _failed)
	quit(0 if _failed == 0 else 1)
