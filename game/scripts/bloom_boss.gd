class_name BloomBoss
extends CharacterBody2D
## Milestone 5 boss — the Rot Bloom. A rooted organism that cycles through a
## readable attack loop and opens a short weak window where it can be hurt.
##
## Loop: idle (0.4 s) -> telegraph (TELEGRAPH) -> attack (0.25 s) ->
## exposed (WEAK_WINDOW) -> idle. `lash` and `spore` alternate each cycle; the
## attack name is carried by `phase_changed` for HUD/demo feedback.
##
## Damage is distance-based, never a physics collision, so the player is never
## wedged into geometry by the boss body. Body damage is accepted only while
## `phase == "exposed"` — holding the burst cannot win the fight. The boss joins
## the existing "predator" group so `PlayerController.spike_burst()` can hit it
## without any change to player.gd.

const MAX_HEALTH := 6
const ATTACK_DAMAGE := 1
const TELEGRAPH := 0.6
const WEAK_WINDOW := 1.5
const RADIUS := 60.0
const GROUP := "predator"

const IDLE_TIME := 0.4
const ATTACK_TIME := 0.25

signal defeated
signal phase_changed(phase: String)

var player: PlayerController = null
var health: int = MAX_HEALTH
# GDScript forbids a variable sharing a name with a signal, so the boolean
# state is `is_defeated` while `defeated` remains the signal (Task 3 wires it).
var is_defeated: bool = false
var phase: String = "idle"

var _phase_time := 0.0
var _last_phase := "idle"
var _attack_hit := false
var _attack_index := 0
var _attack_name := "lash"
var _t := 0.0
var _body: Sprite2D
var _core: Sprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 0 # damage is distance-based; no physics contact needed
	_build_visual()
	_last_phase = phase


func set_player(p: PlayerController) -> void:
	player = p


func phase_name() -> String:
	return phase


## Exposed so the stage HUD can show a boss's real maximum. FinalBoss overrides
## this with its larger pool; subclasses must keep this contract.
func max_health() -> int:
	return MAX_HEALTH


func is_vulnerable() -> bool:
	return phase == "exposed" and not is_defeated


## Returns true when the hit landed. `defeated` fires exactly once, on the
## transition to zero health; a defeated boss is inert and refuses all hits.
func take_damage(amount: int) -> bool:
	if is_defeated or not is_vulnerable():
		return false
	health = maxi(health - amount, 0)
	if health == 0:
		is_defeated = true
		velocity = Vector2.ZERO
		defeated.emit()
	return true


func reset() -> void:
	health = MAX_HEALTH
	is_defeated = false
	phase = "idle"
	_phase_time = 0.0
	_last_phase = "idle"
	_attack_hit = false
	_attack_index = 0
	_attack_name = "lash"
	velocity = Vector2.ZERO
	if _body != null:
		_body.modulate.a = 1.0
	if _core != null:
		_core.modulate.a = 1.0


func _duration_for(p: String) -> float:
	match p:
		"idle":
			return IDLE_TIME
		"telegraph":
			return TELEGRAPH
		"attack":
			return ATTACK_TIME
		"exposed":
			return WEAK_WINDOW
	return IDLE_TIME


func _next_phase() -> String:
	match phase:
		"idle":
			return "telegraph"
		"telegraph":
			return "attack"
		"attack":
			return "exposed"
		"exposed":
			return "idle"
	return "idle"


## Label carried by `phase_changed`. Non-attack phases are their own name;
## the attack phase also names which of the two attacks is active.
func _phase_label() -> String:
	if phase == "attack":
		return "attack:%s" % _attack_name
	return phase


func _on_enter_phase() -> void:
	_phase_time = 0.0
	_attack_hit = false
	if phase == "attack":
		_attack_name = "lash" if _attack_index % 2 == 0 else "spore"
		_attack_index += 1
	phase_changed.emit(_phase_label())


func _try_hit_player() -> void:
	if player == null or player.dead:
		return
	if global_position.distance_to(player.global_position) <= RADIUS:
		player.take_damage(ATTACK_DAMAGE, global_position)


func _physics_process(delta: float) -> void:
	_t += delta
	if is_defeated:
		_fade(delta)
		velocity = Vector2.ZERO
		return

	_phase_time += delta
	# Detect entry by comparison rather than only on internal transitions, so a
	# direct `phase` assignment (tests, scene setup) is honoured as well.
	if phase != _last_phase:
		_on_enter_phase()
		_last_phase = phase

	# At most one hit per attack phase; checked every frame so the player can
	# still be caught if they wander into range mid-attack.
	if phase == "attack" and not _attack_hit:
		_try_hit_player()
		_attack_hit = true

	_update_visual()
	if _phase_time >= _duration_for(phase):
		phase = _next_phase()


func _art_key() -> String:
	return "bloom"


func _build_visual() -> void:
	# A larger, two-layer parasitic bloom: magenta/green radial petals around a
	# bright core — deliberately distinct from predator.gd's single red disc.
	_body = Sprite2D.new()
	var art := GenesisArt.texture(_art_key())
	if art != null:
		_body.name = "GeneratedBody"
		_body.texture = art
		_body.scale = GenesisArt.scale_for(art, RADIUS * 4.0)
		add_child(_body)
		return
	var grad := Gradient.new()
	grad.set_color(0, Color(0.92, 0.22, 0.78, 1.0))
	grad.set_color(1, Color(0.08, 0.30, 0.18, 0.0))
	grad.add_point(0.45, Color(0.30, 0.88, 0.46, 0.85))
	grad.add_point(0.75, Color(0.50, 0.10, 0.62, 0.6))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	_body.texture = tex
	_body.scale = Vector2.ONE * (RADIUS / 32.0)
	add_child(_body)

	_core = Sprite2D.new()
	var core_grad := Gradient.new()
	core_grad.set_color(0, Color(1.0, 0.95, 0.62, 1.0))
	core_grad.set_color(1, Color(1.0, 0.28, 0.70, 0.0))
	var core_tex := GradientTexture2D.new()
	core_tex.gradient = core_grad
	core_tex.width = 64
	core_tex.height = 64
	core_tex.fill = GradientTexture2D.FILL_RADIAL
	core_tex.fill_from = Vector2(0.5, 0.5)
	core_tex.fill_to = Vector2(0.5, 1.0)
	_core.texture = core_tex
	_core.scale = Vector2.ONE * (RADIUS / 64.0)
	add_child(_core)


func _update_visual() -> void:
	if _body == null:
		return
	var rate := 1.0
	match phase:
		"telegraph":
			rate = 3.2
		"attack":
			rate = 2.2
		"exposed":
			rate = 0.5
	var alpha := 0.45 if phase == "exposed" else 1.0
	var pulse := 0.94 + 0.06 * sin(_t * rate * TAU)
	_body.scale = GenesisArt.scale_for(_body.texture, RADIUS * 4.0) * pulse
	_body.modulate.a = alpha
	if _core != null:
		_core.scale = Vector2.ONE * (RADIUS / 64.0) * (0.9 + 0.1 * sin(_t * rate * TAU + 0.8))
		_core.modulate.a = alpha


func _fade(delta: float) -> void:
	if _body != null:
		_body.modulate.a = maxf(_body.modulate.a - delta * 2.0, 0.0)
	if _core != null:
		_core.modulate.a = maxf(_core.modulate.a - delta * 2.0, 0.0)
