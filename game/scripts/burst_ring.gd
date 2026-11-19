class_name BurstRing
extends Node2D
## Visual for the first offensive body part (Milestone 3).
##
## A single expanding ring that fades out: the ability's only feedback, since
## the project still has no audio. Owns nothing but its own animation, so the
## prototype can spawn one per burst and forget it.

var target_radius := 130.0
var life := 0.35
var color := Color(1.0, 0.86, 0.46)

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= life:
		queue_free()


func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var r := lerpf(34.0, target_radius, k)
	var a := 1.0 - k
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 56, Color(color.r, color.g, color.b, a), 4.0)
	draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 48, Color(color.r, color.g, color.b, a * 0.45), 2.0)
