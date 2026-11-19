class_name Predator
extends CharacterBody2D
## Milestone 2 hostile organism — the first thing in the prototype that can hurt
## the player.
##
## Deliberately simple and readable: patrol horizontally inside a band, chase
## when the player is within DETECT_RANGE, and deal contact damage closer than
## TOUCH_RANGE. Chase speed (165) is below the player's swim cap (260) so
## fleeing is always possible — an unwinnable chase would make feeding a trap
## rather than a decision.
##
## Damage is distance-based rather than a physical collision so the player can
## never be wedged into room geometry by the enemy body.

const PATROL_SPEED := 70.0
const CHASE_SPEED := 165.0
const DETECT_RANGE := 420.0
const TOUCH_RANGE := 66.0
const DAMAGE := 1
const RADIUS := 26.0
const GROUP := "predator"
const MAX_HEALTH := 2
# How long a shoved organism is reeling: no chase, no bite.
const STAGGER_TIME := 0.8

signal killed

var player: PlayerController = null
var patrol_min_x := 0.0
var patrol_max_x := 0.0
var facing := 1.0
var chasing := false
var health := MAX_HEALTH
var defeated := false
var stagger := 0.0

var _t := 0.0
var _body: Sprite2D


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 8
	collision_mask = 2 # the room's static slabs
	if get_node_or_null("Shape") == null:
		var shape := CollisionShape2D.new()
		shape.name = "Shape"
		var circle := CircleShape2D.new()
		circle.radius = RADIUS
		shape.shape = circle
		add_child(shape)
	_build_visual()


func _build_visual() -> void:
	_body = Sprite2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.95, 0.45, 0.38, 0.95))
	grad.set_color(1, Color(0.45, 0.08, 0.12, 0.0))
	grad.add_point(0.5, Color(0.72, 0.18, 0.22, 0.75))
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


func _physics_process(delta: float) -> void:
	_t += delta
	if defeated:
		# Fade out after being killed; no further movement or damage.
		if _body != null:
			_body.modulate.a = maxf(_body.modulate.a - delta * 2.5, 0.0)
		velocity = Vector2.ZERO
		return
	if player == null:
		velocity = Vector2.ZERO
		return

	if stagger > 0.0:
		stagger -= delta
		velocity = Vector2.ZERO
		_pulse(0.5)
		return

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	chasing = not player.dead and dist <= DETECT_RANGE

	if player.dead:
		velocity = velocity.move_toward(Vector2.ZERO, 280.0 * delta)
	elif chasing:
		velocity = to_player.normalized() * CHASE_SPEED
	else:
		if global_position.x <= patrol_min_x:
			facing = 1.0
		elif global_position.x >= patrol_max_x:
			facing = -1.0
		velocity = Vector2(facing * PATROL_SPEED, 0.0)

	move_and_slide()
	if is_on_wall():
		facing = -facing

	if not player.dead and global_position.distance_to(player.global_position) <= TOUCH_RANGE:
		player.take_damage(DAMAGE, global_position)

	# Visual: pulse faster while hunting so the state is legible at a glance.
	_pulse(1.4 if chasing else 0.6)


func _pulse(rate: float) -> void:
	if _body == null:
		return
	var pulse := 0.94 + 0.06 * sin(_t * rate * TAU)
	_body.scale = Vector2.ONE * (RADIUS / 32.0) * pulse


## Pushes the organism out to `distance` from a point, never closer. Used by the
## evolution shockwave so the body has room at the moment it changes.
## Returns how far it actually moved (0 when already clear).
func shove_away_from(from: Vector2, distance: float) -> float:
	if defeated:
		return 0.0
	var away := global_position - from
	if away.length() >= distance:
		return 0.0
	if away.length() < 0.001:
		away = Vector2.RIGHT
	var target := from + away.normalized() * distance
	var moved := target - global_position
	global_position = target
	velocity = Vector2.ZERO
	stagger = STAGGER_TIME
	return moved.length()


## Returns true when the hit landed. The killed signal fires exactly once.
func take_damage(amount: int) -> bool:
	if defeated:
		return false
	health = maxi(health - amount, 0)
	if health == 0:
		defeated = true
		chasing = false
		velocity = Vector2.ZERO
		killed.emit()
	return true
