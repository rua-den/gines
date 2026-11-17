extends SceneTree
## Headless regression check: GRIP detach direction.
##
## Contract (see player.gd): while gripped, pushing AWAY from the surface
## detaches to SWIM; pushing INTO the surface or sliding ALONG it keeps
## the grip. Checked on a floor and on a ceiling (platform underside).
##
## Run (project must be imported once on a fresh clone):
##   godot --headless --audio-driver Dummy --path game \
##     --script res://tests/grip_detach_check.gd
## Exit code 0 = all cases pass, 1 = at least one failure.

var _failures := 0


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _add_slab(root: Node, center: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 2 # the player's collision_mask
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4000, 100)
	shape.shape = rect
	body.add_child(shape)
	body.position = center
	root.add_child(body)


## surface: "floor" (top at y=1000) or "ceiling" (bottom at y=800).
func _case(surface: String, hold: Vector2, expect: String, label: String) -> void:
	var root := Node2D.new()
	get_root().add_child(root)
	_add_slab(root, Vector2(0, 1050)) # floor, top surface y = 1000
	_add_slab(root, Vector2(0, 750)) # ceiling, bottom surface y = 800
	var p: PlayerController = load("res://scenes/player.tscn").instantiate()
	p.position = Vector2(0, 900)
	root.add_child(p)
	p.demo_active = true

	p.demo_dir = Vector2.DOWN if surface == "floor" else Vector2.UP
	await _frames(120)
	p.demo_dir = Vector2.ZERO
	await _frames(5)
	p.demo_grip_pressed = true
	await _frames(3)
	var gripped := p.state_name() == "GRIP"

	p.demo_dir = hold
	await _frames(30)
	var got := p.state_name()
	var ok := gripped and got == expect
	if not ok:
		_failures += 1
	print("[T] %s %-34s gripped=%s result=%s expect=%s" % [
		"PASS" if ok else "FAIL", label, gripped, got, expect])
	root.queue_free()
	await _frames(2)


func _init() -> void:
	await _frames(2)
	await _case("floor", Vector2.UP, "SWIM", "floor: push away (up) detaches")
	await _case("floor", Vector2.DOWN, "GRIP", "floor: push into (down) holds")
	await _case("floor", Vector2.RIGHT, "GRIP", "floor: slide along holds")
	await _case("ceiling", Vector2.DOWN, "SWIM", "ceiling: push away (down) detaches")
	await _case("ceiling", Vector2.UP, "GRIP", "ceiling: push into (up) holds")
	await _case("ceiling", Vector2.RIGHT, "GRIP", "ceiling: slide along holds")
	print("[T] grip_detach_check: ", "ALL PASS" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)
