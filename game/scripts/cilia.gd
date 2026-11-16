extends Node2D
## Procedural cilia fringe: sine-waved hairs drawn around the membrane rim.
## One Node2D, one _draw() call, ~44 hairs. No sprites, no animation frames.
## The wave travels around the rim in sync with the swim stroke.

var radius := 110.0
var count := 60
var hair_len := 16.0
var _phase := 0.0
var _stroke := 0.0

func set_phase(p: float, stroke: float) -> void:
	_phase = p
	_stroke = stroke
	queue_redraw()

func _draw() -> void:
	for i in count:
		var a := TAU * float(i) / float(count)
		var dir := Vector2(cos(a), sin(a))
		var side := dir.orthogonal()
		# Wave travelling around the rim, plus a backward sweep on the stroke.
		var wave := sin(TAU * _phase + a * 3.0) * 0.45 + _stroke * 0.4
		var sway := sin(TAU * _phase + a * 3.0 + 1.2)
		var len_f := 0.8 + 0.25 * sin(a * 2.0 + 1.0)
		var root := dir * (radius - 2.0)
		var mid := dir * (radius + hair_len * len_f * 0.45) + side * wave * 5.0
		var tip := dir * (radius + hair_len * len_f * (0.85 + 0.3 * sway)) + side * wave * 8.0
		draw_line(root, mid, Color(0.87, 0.97, 0.93, 0.50), 1.4, true)
		draw_line(mid, tip, Color(0.87, 0.97, 0.93, 0.28), 1.0, true)
