extends RefCounted
## Generated one-shot cues, separate from gameplay state. Each actor can own
## at most one voice per cue; repeated same-cue requests restart that voice.

const AUDIO_DIR := "res://assets/genesis/audio/"
const CUES := [&"pickup", &"burst", &"damage", &"evolve", &"death"]


static func play(parent: Node, cue: StringName) -> void:
	if not CUES.has(cue) or not parent.is_inside_tree() or parent.is_queued_for_deletion():
		return
	var name := "GeneratedAudio_" + String(cue)
	var voice := parent.get_node_or_null(NodePath(name)) as AudioStreamPlayer
	if voice == null:
		var path := AUDIO_DIR + String(cue) + ".wav"
		if not ResourceLoader.exists(path, "AudioStreamWAV"):
			return
		var clip := load(path) as AudioStreamWAV
		if clip == null:
			return
		voice = AudioStreamPlayer.new()
		voice.name = name
		voice.stream = clip
		parent.add_child(voice)
	voice.play()
