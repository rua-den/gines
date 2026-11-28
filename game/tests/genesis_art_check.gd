extends SceneTree
## Run after a Godot import, add -- --require-art for generated asset bundles.
## Plain source checkouts still exercise the original fallback.

var _failures := 0


func _expect(ok: bool, label: String) -> void:
	print("[T] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var require_art := OS.get_cmdline_user_args().has("--require-art")
	if require_art:
		for key in ["player_base", "player_evolved", "predator", "bloom",
				"final_boss", "mote", "evolution_zone", "stone", "growth",
				"hazard", "gate", "world_backdrop", "menu_backdrop", "ui_panel",
				"checkpoint", "goal"]:
			_expect(GenesisArt.texture(key) != null, "%s imports as Texture2D" % key)
		for i in range(1, 10):
			var key := "world_map%02d" % i
			var backdrop := GenesisArt.texture(key)
			_expect(backdrop != null and backdrop.get_size() == Vector2(960.0, 540.0),
				"%s imports at viewport dimensions" % key)
		_expect(GenesisArt.frames("spike_burst") != null, "Spore frames import")

	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	var visual := player.get_node("Visual")
	var expect_body := GenesisArt.texture("player_base") != null \
		and GenesisArt.texture("player_evolved") != null
	var sprite := visual.get_node_or_null("GeneratedBody") as Sprite2D
	_expect((sprite != null) == expect_body, "paired player skin or procedural fallback")
	if sprite != null:
		_expect(sprite.texture == GenesisArt.texture("player_base"), "player starts unevolved")
		visual.call("set_evolved", true)
		_expect(sprite.texture == GenesisArt.texture("player_evolved"), "evolution swaps authored texture")
		visual.call("set_controlled", 0.016, Vector2.RIGHT, 1.0)
	var collision := player.get_node("CollisionShape2D") as CollisionShape2D
	_expect(is_equal_approx((collision.shape as CircleShape2D).radius, 55.0),
		"player collision diameter unchanged")
	player.free()

	for key in ["predator", "bloom", "final_boss", "mote"]:
		var entity: Node2D
		match key:
			"predator": entity = Predator.new()
			"bloom": entity = BloomBoss.new()
			"final_boss": entity = FinalBoss.new()
			"mote": entity = Absorbable.new()
		root.add_child(entity)
		var body := entity.get_node_or_null("GeneratedBody") as Sprite2D
		var tex := GenesisArt.texture(key)
		_expect((body == null and tex == null) or (body != null and body.texture == tex),
			"entity skin or fallback: " + key)
		entity.free()

	var zone := EvolutionZone.new()
	root.add_child(zone)
	_expect(zone.get("_art") == GenesisArt.texture("evolution_zone"), "evolution zone uses art if present")
	_expect(zone.in_range(Vector2(120.0, 0.0)) and not zone.in_range(Vector2(121.0, 0.0)),
		"evolution range unchanged")
	zone.free()
	var ring := BurstRing.new()
	root.add_child(ring)
	var anim := ring.get_node_or_null("GeneratedBurst") as AnimatedSprite2D
	var burst := GenesisArt.frames("spike_burst")
	_expect((anim != null) == (burst != null), "one-shot VFX or procedural fallback")
	if anim != null:
		_expect(not burst.get_animation_loop(&"default") and
			is_equal_approx(burst.get_animation_speed(&"default"), 24.0) and
			burst.get_frame_count(&"default") == 8, "exact imported burst timing")
	ring.free()

	var stage := Node2D.new()
	root.add_child(stage)
	var rect := Rect2(100, 30, 250, 70)
	var slab := RoomBuilder.add_slab(stage, rect, Color.TEAL, Color.WHITE, "hazard")
	var shape := slab.get_child(0) as CollisionShape2D
	_expect((shape.shape as RectangleShape2D).size == rect.size and shape.position == rect.get_center()
		and slab.collision_layer == 2, "terrain visuals preserve collider dimensions and layer")
	var surface := slab.get_node_or_null("GeneratedSurface") as Polygon2D
	var art := GenesisArt.texture("hazard")
	_expect((surface == null and art == null) or (surface != null and surface.texture == art
		and surface.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED), "terrain tiles or flat fallback")
	stage.free()

	var menu := (load("res://scenes/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	var image := menu.get_node_or_null("GeneratedBackdrop") as TextureRect
	var desired := GenesisArt.texture("menu_backdrop")
	if desired == null:
		desired = GenesisArt.texture("world_backdrop")
	_expect((image == null and desired == null) or (image != null and image.texture == desired
		and image.mouse_filter == Control.MOUSE_FILTER_IGNORE), "menu backdrop or flat fallback")
	menu.free()

	var map := (load("res://scenes/map03.tscn") as PackedScene).instantiate()
	root.add_child(map)
	var stage_backdrop := map.get_node_or_null(
		"Backdrop/BackgroundLayer/GeneratedBackdrop") as TextureRect
	var desired_stage := GenesisArt.texture("world_map03")
	if desired_stage == null:
		desired_stage = GenesisArt.texture("world_backdrop")
	_expect((stage_backdrop == null and desired_stage == null) or
		(stage_backdrop != null and stage_backdrop.texture == desired_stage and
		(stage_backdrop.get_parent() as CanvasLayer).layer == -2), "actual map keeps background behind actors")
	if require_art:
		var themed := 0
		for one in map.get_children():
			if one is StaticBody2D and one.get_node_or_null("GeneratedSurface") != null:
				themed += 1
		_expect(themed >= 3, "actual map binds generated materials to its stage slabs")
		var map_player := map.get("player") as PlayerController
		var map_boss := map.get("boss") as BloomBoss
		var map_mote := map.get_tree().get_first_node_in_group(Absorbable.GROUP) as Absorbable
		_expect(map_player != null and map_player.has_node("Visual/GeneratedBody"), "actual map player binds generated skin")
		_expect(map_boss != null and map_boss.has_node("GeneratedBody"), "actual map Bloom binds generated skin")
		_expect(map_mote != null and map_mote.has_node("GeneratedBody"), "actual map mote binds generated skin")
		_expect(map.has_node("Backdrop/GeneratedMarker"), "actual stage shows checkpoint art")
		map.call("_on_boss_defeated")
		_expect(map.has_node("CompletionMarker/GeneratedMarker"), "completion shows goal art")
		var panel := GenesisArt.panel_style(StyleBoxFlat.new()) as StyleBoxTexture
		_expect(panel != null and panel.texture == GenesisArt.texture("ui_panel"), "UI panels bind generated skin")
	map.free()
	print("[T] genesis_art_check: ", "ALL PASS" if _failures == 0 else "%d FAILED" % _failures)
	quit(0 if _failures == 0 else 1)
