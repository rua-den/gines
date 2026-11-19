class_name Absorbable
extends Node2D
## A nutrient mote — the Milestone 2 food source.
##
## Contract: the player channels it by holding `interact` within ABSORB_RANGE.
## This node owns the channel progress (so a cancelled channel cannot leave
## stale progress behind), reports its nutrition value once, and then leaves the
## `absorbable` group so it can never be eaten twice.
##
## Visuals only: a soft golden glow that bobs, pulses faster while being
## channelled, and bursts when consumed. No collision shape is needed — target
## selection is distance-based (see player.gd) and there are only a few motes.

const GROUP := "absorbable"

var nutrition_value := 10.0
var radius := 24.0
var drift := true
var drift_amplitude := 22.0
var drift_speed := 0.8

var progress := 0.0
var consumed := false

var _origin := Vector2.ZERO
var _t := 0.0
var _burst := 0.0
var _body: Sprite2D


func _ready() -> void:
	add_to_group(GROUP)
	_origin = position
	_body = Sprite2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.93, 0.62, 0.95))
	grad.set_color(1, Color(0.98, 0.72, 0.22, 0.0))
	grad.add_point(0.55, Color(1.0, 0.82, 0.36, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	_body.texture = tex
	var s: float = radius / 32.0
	_body.scale = Vector2(s, s)
	add_child(_body)


func _process(delta: float) -> void:
	_t += delta
	if consumed:
		# Burst: expand and fade, then stop drawing.
		if _burst > 0.0:
			_burst = maxf(_burst - delta * 3.0, 0.0)
			var grow: float = 1.0 + (1.0 - _burst) * 1.2
			_body.scale = Vector2.ONE * (radius / 32.0) * grow
			_body.modulate.a = _burst
		else:
			_body.visible = false
		return
	if drift:
		position = _origin + Vector2(0, sin(_t * drift_speed * TAU) * drift_amplitude)
	# Pulse faster while being channelled so the cost is visible.
	var rate := 2.0 + progress * 6.0
	var pulse := 0.85 + 0.15 * sin(_t * rate * TAU)
	_body.scale = Vector2.ONE * (radius / 32.0) * pulse


func channel(delta: float) -> void:
	progress += delta


func cancel_channel() -> void:
	progress = 0.0


## Marks the mote eaten and returns what it is worth; 0 on a second call.
func consume() -> float:
	if consumed:
		return 0.0
	consumed = true
	progress = 0.0
	_burst = 1.0
	remove_from_group(GROUP)
	return nutrition_value
