class_name RoomBuilder
extends RefCounted
## Shared room geometry for the M1/M2 rooms and the M5 boss arena.
##
## The six standard slabs used to be duplicated in prototype.gd and
## movement_test.gd. build_room() recreates them with the same coordinates,
## colors and collision layers; add_slab() is the low-level primitive and takes
## colors explicitly so a caller can draw differently-colored slabs.
## Pure geometry only: each scene still draws its own background.

const SLAB := Color(0.10, 0.32, 0.30)
const SLAB_EDGE := Color(0.56, 0.96, 0.89)


## Adds one solid, visible slab to [param parent]. The body, collision shape,
## polygon and top edge are created in the same order and with the same values
## as the original per-scene `_add_static_rect`.
static func add_slab(parent: Node2D, rect: Rect2, color: Color, edge: Color) -> StaticBody2D:
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var x1: float = rect.end.x
	var y1: float = rect.end.y
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var shape_rect := RectangleShape2D.new()
	shape_rect.size = Vector2(x1 - x0, y1 - y0)
	shape.shape = shape_rect
	shape.position = Vector2((x0 + x1) / 2.0, (y0 + y1) / 2.0)
	body.add_child(shape)
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1),
	])
	poly.color = color
	body.add_child(poly)
	var line := Line2D.new()
	line.points = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0)])
	line.width = 3.0
	line.default_color = edge
	body.add_child(line)
	parent.add_child(body)
	return body


## Builds the six standard slabs (floor, ceiling, two walls, floating platform,
## vertical pillar) plus any caller-supplied extras. With the M1/M2 room these
## are the exact original coordinates: floor (0, FLOOR_TOP, 1920, 1080),
## ceiling (0, 0, 1920, 60), left wall (0, 0, 60, 1080), right wall
## (1860, 0, 1920, 1080), platform (700, 640, 1200, 680) and pillar
## (1400, 700, 1460, FLOOR_TOP).
static func build_room(parent: Node2D, room: Rect2, floor_top: float, extra_slabs: Array[Rect2]) -> void:
	# floor
	add_slab(parent, Rect2(room.position.x, floor_top, room.size.x,
		room.end.y - floor_top), SLAB, SLAB_EDGE)
	# ceiling
	add_slab(parent, Rect2(room.position.x, room.position.y, room.size.x, 60.0), SLAB, SLAB_EDGE)
	# left wall
	add_slab(parent, Rect2(room.position.x, room.position.y, 60.0, room.size.y), SLAB, SLAB_EDGE)
	# right wall
	add_slab(parent, Rect2(room.end.x - 60.0, room.position.y, 60.0, room.size.y), SLAB, SLAB_EDGE)
	# floating platform
	add_slab(parent, Rect2(700.0, 640.0, 1200.0 - 700.0, 680.0 - 640.0), SLAB, SLAB_EDGE)
	# vertical pillar
	add_slab(parent, Rect2(1400.0, 700.0, 1460.0 - 1400.0, floor_top - 700.0), SLAB, SLAB_EDGE)
	for rect in extra_slabs:
		add_slab(parent, rect, SLAB, SLAB_EDGE)
