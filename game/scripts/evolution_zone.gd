class_name EvolutionZone
extends Node2D
## The first evolution site (Milestone 3): a golden alcove that activates when
## the requirement is met.
##
## Kept deliberately dumb — it owns a radius and a look, not the rule. The scene
## decides whether evolution is allowed, so the requirement stays in one place
## (player.can_evolve()) and stays testable headlessly.

const RADIUS := 120.0

var used := false

var _t := 0.0


func in_range(pos: Vector2) -> bool:
	return global_position.distance_to(pos) <= RADIUS


func mark_used() -> void:
	used = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 1.6)
	var base := Color(0.95, 0.62, 0.22) if used else Color(0.95, 0.76, 0.31)
	# Ring plus a soft inner wash; both dim once the site has been used.
	draw_circle(Vector2.ZERO, RADIUS, Color(base.r, base.g, base.b, 0.06 + 0.05 * pulse))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(base.r, base.g, base.b, 0.35 + 0.25 * pulse), 3.0)
	draw_arc(Vector2.ZERO, RADIUS * 0.72, 0.0, TAU, 48, Color(base.r, base.g, base.b, 0.18), 2.0)
	for i in 8:
		var ang := TAU * float(i) / 8.0 + _t * 0.3
		var p := Vector2(cos(ang), sin(ang)) * RADIUS * 0.86
		draw_circle(p, 3.0 + 2.0 * pulse, Color(base.r, base.g, base.b, 0.7))
