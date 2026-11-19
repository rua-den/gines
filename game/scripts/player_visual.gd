extends Node2D
## Player visual (CHR-002 stage 2, ported from EXP-001 protagonist).
## Layered radial-gradient textures + rim-light shader + procedural cilia.
## The CharacterBody2D owns position; this node only handles the look.
## Base artwork radius is 110 px; the parent scales this node to 0.5 so the
## visual radius (55) matches the physics collision circle.

const PERIOD := 2.4
const BODY_R := 110.0

var base_scale := 0.5
var health := 1.0
var gripped := false
var evolved := false

var body: Sprite2D
var nucleus_glow: Sprite2D
var nucleus: Sprite2D
var dots: Array = []
var cilia: Node2D
var spikes: Node2D
var _t := 0.0


func _ready() -> void:
	# Cilia first: drawn behind the body so hair roots hide under the rim.
	cilia = preload("res://scripts/cilia.gd").new()
	cilia.radius = BODY_R
	add_child(cilia)

	body = Sprite2D.new()
	body.texture = _radial_texture(256, [
		[0.0, Color(0.48, 0.80, 0.72, 1.0)],
		[0.45, Color(0.25, 0.68, 0.60, 1.0)],
		[0.80, Color(0.14, 0.47, 0.42, 1.0)],
		[1.0, Color(0.08, 0.31, 0.28, 1.0)],
	], Vector2(0.5, 0.42), Vector2(0.5, 0.98))
	var rim_mat := ShaderMaterial.new()
	rim_mat.shader = preload("res://shaders/body_rim.gdshader")
	body.material = rim_mat
	body.scale = Vector2(BODY_R * 2.0 / 256.0, BODY_R * 2.0 / 256.0)
	add_child(body)

	# Bioluminescent cyan dots on the membrane.
	var dot_tex: GradientTexture2D = _radial_texture(64, [
		[0.0, Color(0.75, 1.0, 0.94, 1.0)],
		[1.0, Color(0.45, 0.9, 0.85, 0.0)],
	], Vector2(0.5, 0.5), Vector2(0.5, 1.0))
	var dot_defs := [
		[Vector2(-52, -38), 0.55],
		[Vector2(38, -52), 0.45],
		[Vector2(58, 30), 0.5],
		[Vector2(-30, 58), 0.4],
	]
	for d in dot_defs:
		var s := Sprite2D.new()
		s.texture = dot_tex
		s.position = d[0]
		s.scale = Vector2(d[1], d[1])
		add_child(s)
		dots.append(s)

	# Evolved body: a ring of golden spikes. Hidden until evolution, so the
	# transformation is visible rather than implied (BACKLOG M3).
	spikes = Node2D.new()
	for i in 14:
		var ang := TAU * float(i) / 14.0
		var a := ang - 0.085
		var b := ang + 0.085
		var r0 := BODY_R * 0.9
		var r1 := BODY_R * (1.18 if i % 2 == 0 else 1.08)
		var spike := Polygon2D.new()
		spike.polygon = PackedVector2Array([
			Vector2(cos(a), sin(a)) * r0,
			Vector2(cos(b), sin(b)) * r0,
			Vector2(cos(ang), sin(ang)) * r1,
		])
		spike.color = Color(0.93, 0.79, 0.34, 0.9)
		spikes.add_child(spike)
	spikes.visible = false
	add_child(spikes)

	# Golden nucleus: additive glow halo + solid bright core.
	var glow_tex: GradientTexture2D = _radial_texture(256, [
		[0.0, Color(1.0, 0.85, 0.42, 0.9)],
		[0.5, Color(0.97, 0.72, 0.2, 0.45)],
		[1.0, Color(0.97, 0.72, 0.2, 0.0)],
	], Vector2(0.5, 0.5), Vector2(0.5, 1.0))
	nucleus_glow = Sprite2D.new()
	nucleus_glow.texture = glow_tex
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	nucleus_glow.material = add_mat
	nucleus_glow.scale = Vector2(0.85, 0.85)
	add_child(nucleus_glow)

	var core_tex: GradientTexture2D = _radial_texture(128, [
		[0.0, Color(1.0, 0.93, 0.66, 1.0)],
		[0.55, Color(0.98, 0.78, 0.28, 1.0)],
		[0.85, Color(0.85, 0.55, 0.12, 1.0)],
		[1.0, Color(0.85, 0.55, 0.12, 0.0)],
	], Vector2(0.5, 0.42), Vector2(0.5, 0.98))
	nucleus = Sprite2D.new()
	nucleus.texture = core_tex
	nucleus.scale = Vector2(0.52, 0.52)
	add_child(nucleus)


func _radial_texture(size: int, stops: Array, from: Vector2, to: Vector2) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, stops[0][1])
	grad.set_color(1, stops[stops.size() - 1][1])
	for i in range(1, stops.size() - 1):
		grad.add_point(stops[i][0], stops[i][1])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = size
	gt.height = size
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = from
	gt.fill_to = to
	return gt


func set_evolved(value: bool) -> void:
	evolved = value
	if spikes != null:
		spikes.visible = value
	if body != null:
		body.modulate = Color(1.16, 1.05, 0.92) if value else Color.WHITE


## Called every physics frame by the parent CharacterBody2D.
## dir: movement input direction. speed_frac: 0..1 of max swim speed.
func set_controlled(delta: float, dir: Vector2, speed_frac: float) -> void:
	_t += delta
	var p := fmod(_t, PERIOD) / PERIOD
	# Gripped: cilia flatten and the stroke calms (the cell is holding on).
	var stroke_amp := 0.35 if gripped else 1.0
	var stroke := sin(TAU * p) * (0.3 + 0.7 * clampf(speed_frac, 0.0, 1.0)) * stroke_amp
	var squash := 0.08 * stroke
	if gripped:
		# Slight vertical flatten while attached.
		scale = Vector2(base_scale * (1.0 + 0.04), base_scale * (1.0 - 0.06))
	else:
		scale = Vector2(base_scale * (1.0 - squash), base_scale * (1.0 + squash))
	var target_rot := 0.0
	if dir.length() > 0.1:
		target_rot = clampf(dir.x * 0.15, -0.15, 0.15)
	rotation = lerp_angle(rotation, target_rot + 0.07 * sin(TAU * p + 0.7), 0.2)
	var pulse := 0.5 + 0.5 * sin(TAU * p - 0.9)
	nucleus_glow.scale = Vector2.ONE * (0.58 + 0.16 * pulse)
	nucleus_glow.modulate.a = (0.42 + 0.28 * pulse) * (0.35 + 0.65 * health)
	nucleus.scale = Vector2.ONE * (0.52 + 0.04 * pulse)
	for i in dots.size():
		var d: Sprite2D = dots[i]
		var dp := 0.5 + 0.5 * sin(TAU * p + float(i) * 1.7)
		d.modulate.a = 0.4 + 0.5 * dp
	cilia.hair_len = 10.0 if gripped else 16.0
	cilia.set_phase(p, stroke)
	if spikes != null and evolved:
		# Slow breathing on the spike ring keeps the new body legible.
		var sp := 1.0 + 0.03 * sin(TAU * p * 2.0)
		spikes.scale = Vector2(sp, sp)
		spikes.rotation = 0.04 * sin(TAU * p)
