class_name SaveState
extends RefCounted
## Prototype progress persistence (Milestone 3).
##
## One ConfigFile, one section, no autoload and no schema version yet — the
## prototype only needs evolution to survive a restart, and a save format that
## matches that need exactly. Deliberately no PlayerController type references
## here so tests and tools can use this without pulling in the controller.
##
## Paths are explicit arguments so tests can use their own file instead of the
## player's real save.

const DEFAULT_PATH := "user://genesis_save.cfg"
const SECTION := "progress"


static func write(path: String, data: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	var existing := read(path)
	for key in existing:
		cfg.set_value(SECTION, key, existing[key])
	for key in data:
		cfg.set_value(SECTION, key, data[key])
	return cfg.save(path)


static func read(path: String) -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return {}
	var out := {}
	for key in cfg.get_section_keys(SECTION):
		out[key] = cfg.get_value(SECTION, key)
	return out


static func clear(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Applies stored progress to a player without charging evolution again.
static func apply_to_player(player: Node, data: Dictionary) -> void:
	if data.is_empty():
		return
	if bool(data.get("evolved", false)) and player.has_method("restore_evolved"):
		player.restore_evolved(true)
	if data.has("nutrition"):
		player.nutrition = float(data["nutrition"])
