class_name BossFight
extends Node2D
## Milestone 5 — the first boss arena.
##
## The corridor before the gate is deliberately self-contained: three nutrient
## motes pay for one evolution at the golden alcove, and only an evolved player
## wakes the Rot Bloom past GATE_X. This is the progression softlock guard — an
## unevolved player sees a dormant bloom and a HUD prompt, never an unwinnable
## fight. Defeat returns the player to the shelter: boss health and energy reset,
## evolution and nutrition persist. The boss is never saved.

const ROOM := Rect2(0, 0, 1920, 1080)
const FLOOR_TOP := 1020.0
const START_POS := Vector2(300, 500)
const ZONE_POS := Vector2(960, 520)
# Three motes × 10Nutrition = the exact EVOLVE_COST, so a fresh player can open
# the gate without a prior save (controller ruling 8).
const MOTE_POSITIONS := [
	Vector2(460, 470), Vector2(640, 560), Vector2(820, 460),
]
const GATE_X := 1100.0
const SHELTER_POS := Vector2(1020, 900)
const BOSS_START := Vector2(1560, 520)
const ROUTE_X := 1820.0
# Named, not counted: a duplicated capture cannot stand in for a missing one.
const M5_SHOTS := ["approach", "telegraph", "weak-window", "victory"]

const BG := Color(0.05, 0.16, 0.18)
const GATE_FILL := Color(0.30, 0.08, 0.24, 0.92)
const GATE_EDGE := Color(0.95, 0.45, 0.72)
const ROUTE_FILL := Color(0.08, 0.22, 0.20, 0.92)
const ROUTE_EDGE := Color(0.40, 0.86, 0.72)
const CORAL := Color(0.95, 0.48, 0.42)
const GOLD := Color(0.95, 0.76, 0.31)
const TEAL_LIGHT := Color(0.56, 0.96, 0.89)

var player: PlayerController
var boss: BloomBoss
var boss_defeated: bool = false
var camera: Camera2D
var zone: EvolutionZone
var motes: Array[Absorbable] = []
var gate: StaticBody2D
var route_gate: StaticBody2D

var health_label: Label
var nutrition_label: Label
var energy_label: Label
var boss_label: Label
var prompt_label: Label
var pause_label: Label

var _paused := false
var _anim := 0.0
var _flash := 0.0
var _save_path := SaveState.DEFAULT_PATH
var _fresh_save := false
var m5_demo := false


func _ready() -> void:
	# The root stays ALWAYS so the pause key works; every actor is PAUSABLE.
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[M5] READY boss arena, viewport ", get_viewport_rect().size)
	for arg in OS.get_cmdline_user_args():
		if arg == "--fresh-save":
			_fresh_save = true
		elif arg == "--m5-demo":
			m5_demo = true
	if _fresh_save:
		SaveState.clear(_save_path)
	_build_background()
	RoomBuilder.build_room(self, ROOM, FLOOR_TOP, [])

	player = $Player
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.global_position = START_POS
	player.nutrition_gained.connect(_on_nutrition)
	player.damaged.connect(_on_damaged)
	player.died.connect(retry)
	player.evolved_now.connect(_on_evolved_now)
	player.burst_fired.connect(_on_burst_fired)

	_build_zone()
	_build_motes()
	_build_boss()
	_build_gates()
	_build_camera()
	_build_hud()
	_load_progress()
	# A restored save has evolved=true but emitted no evolved_now, so open the
	# gate and hand the boss its player explicitly.
	if gate_open():
		_open_gate()
	if m5_demo:
		player.demo_active = true
		print("[M5] demo mode")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and pause_label != null:
		_paused = not _paused
		get_tree().paused = _paused
		pause_label.visible = _paused


func _process(delta: float) -> void:
	_anim += delta
	_flash = maxf(_flash - delta, 0.0)
	if _paused:
		return
	camera.global_position = player.global_position
	_update_hud()
	if not player.dead and not m5_demo and Input.is_action_just_pressed("interact"):
		_try_evolve()


# ------------------------------------------------------------------ gameplay

## The rule stays on the scene: the alcove is only a location, `can_evolve`
## is the requirement. Kept identical to prototype.gd's evolution contract.
func _try_evolve() -> bool:
	if player.evolved or not zone.in_range(player.global_position):
		return false
	if not player.can_evolve():
		_flash = 0.35
		return false
	return player.evolve()


func gate_open() -> bool:
	return player != null and player.evolved


func _on_evolved_now() -> void:
	_open_gate()
	_save_progress()


func _open_gate() -> void:
	if gate == null:
		return
	gate.collision_layer = 0
	gate.collision_mask = 0
	gate.visible = false
	for child in gate.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
	# The boss only becomes active once the gate is open. Never assign it before.
	if boss != null and player != null:
		boss.set_player(player)
	if zone != null:
		zone.mark_used()
	_flash = 0.5
	print("[M5] evolution gate opened")


func _on_boss_defeated() -> void:
	boss_defeated = true
	_disable_body(route_gate)
	_save_progress()
	_flash = 0.5
	print("[M5] bloom defeated — route open")


func _disable_body(body: StaticBody2D) -> void:
	if body == null:
		return
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	for child in body.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)


## Shelter retry: restore the player and the boss, never roll back progress.
func retry() -> void:
	if player == null or boss == null:
		return
	player.global_position = SHELTER_POS
	player.revive()
	boss.reset()
	if camera != null:
		camera.global_position = SHELTER_POS
	print("[M5] shelter retry")


# ------------------------------------------------------------------- storage

func _save_progress() -> void:
	# Demo runs never touch the player's real save. The boss is never stored.
	if m5_demo:
		return
	SaveState.write(_save_path, {"evolved": player.evolved, "nutrition": player.nutrition})


func _load_progress() -> void:
	if m5_demo:
		return
	var data := SaveState.read(_save_path)
	if data.is_empty():
		return
	SaveState.apply_to_player(player, data)
	if player.evolved and zone != null:
		zone.mark_used()
		print("[M5] loaded saved progress: evolved=true nutrition=", player.nutrition)


# ------------------------------------------------------------------- build

func _build_background() -> void:
	var backdrop := CanvasLayer.new()
	backdrop.layer = -2
	add_child(backdrop)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(bg)


func _build_zone() -> void:
	zone = EvolutionZone.new()
	zone.process_mode = Node.PROCESS_MODE_PAUSABLE
	zone.position = ZONE_POS
	add_child(zone)


func _build_motes() -> void:
	for pos in MOTE_POSITIONS:
		var mote := Absorbable.new()
		mote.process_mode = Node.PROCESS_MODE_PAUSABLE
		mote.position = pos
		mote.drift_speed = 0.6 + 0.1 * motes.size()
		add_child(mote)
		motes.append(mote)


func _build_boss() -> void:
	boss = BloomBoss.new()
	boss.position = BOSS_START
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)


func _build_gates() -> void:
	gate = RoomBuilder.add_slab(self,
		Rect2(GATE_X - 20.0, 60.0, 40.0, FLOOR_TOP - 60.0), GATE_FILL, GATE_EDGE)
	gate.name = "EvolutionGate"
	route_gate = RoomBuilder.add_slab(self,
		Rect2(ROUTE_X - 18.0, 60.0, 36.0, FLOOR_TOP - 60.0), ROUTE_FILL, ROUTE_EDGE)
	route_gate.name = "RouteGate"


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


func _on_nutrition(_amount: float) -> void:
	_flash = 0.35


func _on_damaged(_hits_left: int) -> void:
	_flash = 0.35


## The burst's only feedback until there is audio: one expanding ring per shot.
func _on_burst_fired(at: Vector2) -> void:
	var ring := BurstRing.new()
	add_child(ring)
	ring.global_position = at


# ---------------------------------------------------------------------- HUD

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
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_hud() -> void:
	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 10
	add_child(ui)
	var viewport_size := get_viewport_rect().size
	ui.add_child(_make_hud_panel(Rect2(12, 8, 950, 176), CORAL))
	ui.add_child(_make_hud_panel(
		Rect2(12, viewport_size.y - 56, viewport_size.x - 24, 44), TEAL_LIGHT))
	var title := _make_label("GENESIS  /  THE ROT BLOOM", 22, Color(0.98, 0.96, 0.93))
	title.offset_top = 12
	title.offset_bottom = 44
	ui.add_child(title)
	health_label = _make_label("Health ♥♥♥", 20, CORAL)
	health_label.offset_top = 46
	health_label.offset_bottom = 74
	ui.add_child(health_label)
	nutrition_label = _make_label("Nutrition 0", 20, GOLD)
	nutrition_label.offset_left = 260
	nutrition_label.offset_right = 700
	nutrition_label.offset_top = 46
	nutrition_label.offset_bottom = 74
	ui.add_child(nutrition_label)
	energy_label = _make_label("", 16, TEAL_LIGHT)
	energy_label.offset_top = 76
	energy_label.offset_bottom = 100
	energy_label.visible = false
	ui.add_child(energy_label)
	boss_label = _make_label("Bloom dormant", 16, Color(0.95, 0.55, 0.8))
	boss_label.offset_top = 102
	boss_label.offset_bottom = 126
	ui.add_child(boss_label)
	prompt_label = _make_label("Evolve to wake the bloom", 18, GOLD)
	prompt_label.offset_top = 130
	prompt_label.offset_bottom = 160
	ui.add_child(prompt_label)
	var hint := _make_label(
		"WASD — swim  •  hold E near a mote — absorb  •  E at the alcove — evolve  •  J — burst  •  Esc — pause",
		15, Color(0.65, 0.8, 0.78))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -36
	hint.offset_bottom = -12
	ui.add_child(hint)
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
	nutrition_label.modulate = Color(1.6, 1.5, 1.1) if _flash > 0.0 else Color.WHITE

	energy_label.visible = player.evolved
	if player.evolved:
		var energy_pips := ""
		for i in int(player.MAX_ENERGY):
			energy_pips += "●" if i < int(player.energy) else "○"
		energy_label.text = "Energy %s  %.1f/%.0f" % [energy_pips, player.energy, player.MAX_ENERGY]
		energy_label.modulate = Color(1.0, 0.75, 0.65) \
			if player.energy < player.BURST_ENERGY_COST else Color.WHITE

	if boss_defeated:
		boss_label.text = "Bloom withered — route open"
	elif gate_open():
		boss_label.text = "Bloom %d/%d  •  %s" % [boss.health, BloomBoss.MAX_HEALTH, boss.phase_name()]
	else:
		boss_label.text = "Bloom dormant"

	if not gate_open():
		prompt_label.text = "Evolve to wake the bloom"
	elif boss_defeated:
		prompt_label.text = "Route open — swim deeper"
	elif boss.phase == "exposed":
		prompt_label.text = "NOW — strike the exposed core"
	elif boss.phase == "telegraph":
		prompt_label.text = "Telegraph — dodge the bloom"
	else:
		prompt_label.text = "Wait for the core to open"
