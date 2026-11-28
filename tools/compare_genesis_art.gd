extends SceneTree
## Controlled capture of the same actual game scene in two checked-out versions.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("usage: <menu|map01|bloom> <absolute PNG path>")
		quit(1)
		return
	var moment := args[0]
	var scene_path := "res://scenes/main_menu.tscn" if moment == "menu" else (
		"res://scenes/map01.tscn" if moment == "map01" else "res://scenes/map03.tscn")
	seed(741)
	var scene := (load(scene_path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.process_mode = Node.PROCESS_MODE_DISABLED

	var camera_position := Vector2.ZERO
	if moment != "menu":
		var stage := scene as MapStage
		if stage == null or stage.camera == null or stage.player == null or (moment == "bloom" and stage.boss == null):
			push_error("required gameplay actors were not loaded")
			quit(1)
			return
		var camera: Camera2D = stage.camera
		if moment == "bloom":
			var boss_position: Vector2 = stage.boss.global_position
			stage.player.global_position = boss_position + Vector2(-155.0, 30.0)
			stage.player.restore_evolved(true)
			camera.global_position = boss_position + Vector2(-70.0, 10.0)
		else:
			camera.global_position = stage.player.global_position
		camera.position_smoothing_enabled = false
		camera.reset_smoothing()
		camera.make_current()
		camera.force_update_scroll()
		camera_position = camera.get_screen_center_position()

	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	if pixels == null or pixels.is_empty() or pixels.get_width() < 900 or pixels.get_height() < 500:
		push_error("expected a real gameplay viewport")
		quit(1)
		return
	var saved := pixels.save_png(args[1])
	print("CAPTURE: %s %sx%s camera=(%.2f,%.2f)" % [moment, pixels.get_width(), pixels.get_height(), camera_position.x, camera_position.y])
	quit(0 if saved == OK else 1)
