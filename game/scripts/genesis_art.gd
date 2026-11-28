class_name GenesisArt
extends RefCounted
## The authored skin is presentation only. Missing imports leave the original
## procedural visuals working for development and old/sparse checkouts.
const ROOT := "res://assets/genesis/"

static func texture(key: String) -> Texture2D:
	var path := ROOT + key + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null


static func frames(key: String) -> SpriteFrames:
	var path := ROOT + key + ".tres"
	return load(path) as SpriteFrames if ResourceLoader.exists(path, "SpriteFrames") else null


static func scale_for(texture_value: Texture2D, diameter: float) -> Vector2:
	return Vector2.ONE * diameter / maxf(texture_value.get_width(), texture_value.get_height())


## Decorative backgrounds never capture clicks, focus or input.
static func add_backdrop(parent: Node, key: String, fallback_key := "") -> bool:
	var art := texture(key)
	if art == null and not fallback_key.is_empty():
		art = texture(fallback_key)
	if art == null:
		return false
	var visual := TextureRect.new()
	visual.name = "GeneratedBackdrop"
	visual.texture = art
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(visual)
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return true


static func add_marker(parent: Node, key: String, at: Vector2, diameter: float) -> void:
	var art := texture(key)
	if art == null:
		return
	var visual := Sprite2D.new()
	visual.name = "GeneratedMarker"
	visual.texture = art
	visual.scale = scale_for(art, diameter)
	visual.position = at
	parent.add_child(visual)


static func panel_style(fallback: StyleBoxFlat) -> StyleBox:
	var art := texture("ui_panel")
	if art == null:
		return fallback
	var visual := StyleBoxTexture.new()
	visual.texture = art
	visual.set_texture_margin_all(8.0)
	visual.modulate_color = Color(1.0, 1.0, 1.0, fallback.bg_color.a)
	return visual
