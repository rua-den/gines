class_name PlayerController
extends CharacterBody2D
## Player controller — Milestone 1.
##
## Three states, all driven by the central InputMap (move_*, grip):
##   SWIM  — free swimming: acceleration + drift, max 260 px/s.
##   CRAWL — moving along the floor while touching it: max 130 px/s,
##           entered by pressing left/right on the floor, exited by
##           pressing up (swim away) or walking off an edge.
##   GRIP  — attached to a surface (floor, wall, platform underside,
##           ceiling): the player sticks and moves slowly along the
##           surface (90 px/s). Press grip again, or push away from the
##           surface, to detach back to SWIM.
##
## No gravity: this is a fluid environment. Contact is detected with
## move_and_slide() (is_on_floor / is_on_wall / is_on_ceiling).
##
## Demo autopilot support: when demo_active is true, the movement test
## scene drives the player through demo_dir and demo_grip_pressed
## instead of the real input. The physics path is identical.

enum State { SWIM, CRAWL, GRIP }

const SWIM_ACCEL := 900.0
const SWIM_MAX := 260.0
const SWIM_DAMP := 4.0
const CRAWL_ACCEL := 700.0
const CRAWL_MAX := 130.0
const GRIP_SPEED := 90.0
const GRIP_PRESS := 30.0
const GRIP_COOLDOWN := 0.25

# Milestone 2 — absorption and survival.
const ABSORB_RANGE := 90.0
const ABSORB_CHANNEL := 0.75
const FEED_SPEED_CAP := 90.0
const MAX_HEALTH := 3
const INVULN_TIME := 1.0
const KNOCKBACK := 260.0

# Milestone 3 — first evolution and its offensive body part.
const EVOLVE_COST := 30.0
const BURST_RANGE := 130.0
const BURST_COOLDOWN := 0.8
const BURST_DAMAGE := 1

signal nutrition_gained(amount: float)
signal damaged(hits_left: int)
signal died
signal evolved_now
signal burst_fired(at: Vector2)

var state: State = State.SWIM
var grip_normal := Vector2.UP

# Milestone 2 state. Nutrition is the single prototype resource (BACKLOG M2);
# there is deliberately no resource dictionary until a second resource earns one.
var nutrition := 0.0
var health := MAX_HEALTH
var dead := false
var absorb_target: Absorbable = null

# Milestone 3 state.
var evolved := false

# Demo autopilot injection (movement_test.gd sets these).
var demo_active := false
var demo_dir := Vector2.ZERO
var demo_grip_pressed := false
var demo_interact_held := false
var demo_attack_pressed := false

var _grip_cooldown := 0.0
var _invuln := 0.0
var _burst_cooldown := 0.0
var _visual: Node2D
var _state_changes: Array[String] = []


func _ready() -> void:
	_visual = $Visual
	floor_snap_length = 8.0


func state_name() -> String:
	match state:
		State.SWIM:
			return "SWIM"
		State.CRAWL:
			return "CRAWL"
		State.GRIP:
			return "GRIP"
	return "?"


func state_history() -> Array[String]:
	return _state_changes


func _input_dir() -> Vector2:
	if demo_active:
		return demo_dir
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _grip_just_pressed() -> bool:
	if demo_active:
		if demo_grip_pressed:
			demo_grip_pressed = false
			return true
		return false
	return Input.is_action_just_pressed("grip")


func _interact_held() -> bool:
	if demo_active:
		return demo_interact_held
	return Input.is_action_pressed("interact")


func _attack_just_pressed() -> bool:
	if demo_active:
		if demo_attack_pressed:
			demo_attack_pressed = false
			return true
		return false
	return Input.is_action_just_pressed("attack")


## Swim cap for this frame: feeding drags the body down to FEED_SPEED_CAP.
func speed_cap() -> float:
	return FEED_SPEED_CAP if absorb_target != null else SWIM_MAX


func _find_absorb_target() -> Absorbable:
	var best: Absorbable = null
	var best_dist := ABSORB_RANGE
	for node in get_tree().get_nodes_in_group(Absorbable.GROUP):
		var mote := node as Absorbable
		if mote == null or mote.consumed:
			continue
		var d := global_position.distance_to(mote.global_position)
		if d <= best_dist:
			best = mote
			best_dist = d
	return best


## Channels the nearest mote while `interact` is held. Releasing, walking out of
## range, changing target or taking a hit resets the channel without consuming.
func _tick_absorb(delta: float) -> void:
	if dead or not _interact_held():
		_release_absorb()
		return
	var target := _find_absorb_target()
	if target != absorb_target:
		_release_absorb()
		absorb_target = target
	if absorb_target == null:
		return
	absorb_target.channel(delta)
	if absorb_target.progress >= ABSORB_CHANNEL:
		var mote := absorb_target
		absorb_target = null
		var value := mote.consume()
		nutrition += value
		nutrition_gained.emit(value)


func _release_absorb() -> void:
	if absorb_target != null and is_instance_valid(absorb_target):
		absorb_target.cancel_channel()
	absorb_target = null


## Returns true when the hit landed; false during invulnerability or after death.
func take_damage(amount: int, from_pos: Vector2) -> bool:
	if dead or _invuln > 0.0:
		return false
	health = maxi(health - amount, 0)
	_invuln = INVULN_TIME
	_release_absorb()
	var away := global_position - from_pos
	if away.length() < 0.001:
		away = Vector2.UP
	velocity = away.normalized() * KNOCKBACK
	damaged.emit(health)
	if health == 0:
		dead = true
		velocity = Vector2.ZERO
		died.emit()
	return true


## Full health plus a grace window; the scene owns the respawn position.
func revive() -> void:
	health = MAX_HEALTH
	dead = false
	_invuln = INVULN_TIME
	velocity = Vector2.ZERO
	_release_absorb()
	state = State.SWIM


# --------------------------------------------------------------- evolution

func can_evolve() -> bool:
	return not evolved and nutrition >= EVOLVE_COST


## Spends EVOLVE_COST nutrition and permanently changes the body.
func evolve() -> bool:
	if not can_evolve():
		return false
	nutrition -= EVOLVE_COST
	_apply_evolved(true)
	evolved_now.emit()
	return true


## Restores evolved state from a save without charging for it again.
func restore_evolved(value: bool) -> void:
	_apply_evolved(value)


## Extends the damage grace window, e.g. for the transformation moment.
func grant_grace(seconds: float) -> void:
	_invuln = maxf(_invuln, seconds)


func _apply_evolved(value: bool) -> void:
	evolved = value
	if _visual != null and _visual.has_method("set_evolved"):
		_visual.set_evolved(value)


func can_attack() -> bool:
	return evolved and _burst_cooldown <= 0.0


## First offensive body part. Returns false when the body has not evolved yet or
## the cooldown has not elapsed, so "unavailable before evolution" is observable.
func spike_burst() -> bool:
	if not can_attack():
		return false
	_burst_cooldown = BURST_COOLDOWN
	burst_fired.emit(global_position)
	# Predators are looked up by group rather than by type: predator.gd already
	# depends on PlayerController, and a typed reference back would be cyclic.
	for node in get_tree().get_nodes_in_group("predator"):
		if not node.has_method("take_damage"):
			continue
		if global_position.distance_to(node.global_position) <= BURST_RANGE:
			node.take_damage(BURST_DAMAGE)
	return true


func _set_state(next: State) -> void:
	if next == state:
		return
	_state_changes.append("%s->%s" % [state_name(), _name_of(next)])
	state = next
	if _visual != null:
		_visual.gripped = state == State.GRIP


func _name_of(s: State) -> String:
	match s:
		State.SWIM:
			return "SWIM"
		State.CRAWL:
			return "CRAWL"
		State.GRIP:
			return "GRIP"
	return "?"


func _surface_normal() -> Vector2:
	if is_on_floor():
		return Vector2.UP
	if is_on_ceiling():
		return Vector2.DOWN
	if is_on_wall():
		return get_wall_normal()
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	if _grip_cooldown > 0.0:
		_grip_cooldown -= delta
	if _invuln > 0.0:
		_invuln -= delta
	if _burst_cooldown > 0.0:
		_burst_cooldown -= delta
	if dead:
		# No input while defeated: drift to a stop so the retry overlay reads.
		velocity *= exp(-SWIM_DAMP * delta)
		move_and_slide()
		_update_visual(delta, Vector2.ZERO)
		return
	var dir := _input_dir()
	var grip_pressed := _grip_just_pressed()
	_tick_absorb(delta)
	if _attack_just_pressed():
		spike_burst()

	match state:
		State.SWIM:
			_swim(delta, dir)
			# Attach: grip while touching any surface.
			if grip_pressed and _grip_cooldown <= 0.0:
				var n := _surface_normal()
				if n != Vector2.ZERO:
					grip_normal = n
					velocity = Vector2.ZERO
					_set_state(State.GRIP)
			# Crawl: on the floor, pressing sideways without pressing up.
			elif is_on_floor() and dir.x != 0.0 and dir.y >= -0.1:
				_set_state(State.CRAWL)

		State.CRAWL:
			# Move along the floor; gentle downward press keeps contact.
			var target := Vector2(dir.x * CRAWL_MAX, 24.0)
			velocity = velocity.move_toward(target, CRAWL_ACCEL * delta)
			move_and_slide()
			if dir.y < -0.3:
				# Swim away upward.
				_set_state(State.SWIM)
			elif not is_on_floor():
				# Walked off an edge.
				_set_state(State.SWIM)
			elif grip_pressed and _grip_cooldown <= 0.0:
				grip_normal = Vector2.UP
				velocity = Vector2.ZERO
				_set_state(State.GRIP)

		State.GRIP:
			# Move slowly along the surface tangent; press into the
			# surface so contact is maintained.
			var tangent := grip_normal.orthogonal()
			var along: float = dir.dot(tangent)
			velocity = tangent * along * GRIP_SPEED + grip_normal * -GRIP_PRESS
			move_and_slide()
			if grip_pressed and _grip_cooldown <= 0.0:
				_grip_cooldown = GRIP_COOLDOWN
				_set_state(State.SWIM)
			elif dir.dot(grip_normal) > 0.5:
				# Pushing away from the surface (along its outward
				# normal) detaches; pushing into it keeps the grip.
				_grip_cooldown = GRIP_COOLDOWN
				_set_state(State.SWIM)
			elif not (is_on_floor() or is_on_wall() or is_on_ceiling()):
				# Lost the surface.
				_set_state(State.SWIM)

	# Visuals follow the same call the EXP-001 protagonist uses.
	_update_visual(delta, dir)


func _update_visual(delta: float, dir: Vector2) -> void:
	if _visual == null:
		return
	if _visual.has_method("set_controlled"):
		var speed_frac: float = clampf(velocity.length() / SWIM_MAX, 0.0, 1.0)
		_visual.set_controlled(delta, dir, speed_frac)
	# Invulnerable = flicker; defeated = dimmed. Both read without extra UI.
	if dead:
		_visual.modulate.a = 0.3
	elif _invuln > 0.0:
		_visual.modulate.a = 0.45
	else:
		_visual.modulate.a = 1.0


func _swim(delta: float, dir: Vector2) -> void:
	if dir.length() > 0.1:
		velocity += dir.normalized() * SWIM_ACCEL * delta
	else:
		velocity *= exp(-SWIM_DAMP * delta)
	var cap := speed_cap()
	if velocity.length() > cap:
		velocity = velocity.normalized() * cap
	move_and_slide()
