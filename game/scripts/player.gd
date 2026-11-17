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

var state: State = State.SWIM
var grip_normal := Vector2.UP

# Demo autopilot injection (movement_test.gd sets these).
var demo_active := false
var demo_dir := Vector2.ZERO
var demo_grip_pressed := false

var _grip_cooldown := 0.0
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
	var dir := _input_dir()
	var grip_pressed := _grip_just_pressed()

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
	if _visual != null and _visual.has_method("set_controlled"):
		var speed_frac: float = clampf(velocity.length() / SWIM_MAX, 0.0, 1.0)
		_visual.set_controlled(delta, dir, speed_frac)


func _swim(delta: float, dir: Vector2) -> void:
	if dir.length() > 0.1:
		velocity += dir.normalized() * SWIM_ACCEL * delta
	else:
		velocity *= exp(-SWIM_DAMP * delta)
	if velocity.length() > SWIM_MAX:
		velocity = velocity.normalized() * SWIM_MAX
	move_and_slide()
