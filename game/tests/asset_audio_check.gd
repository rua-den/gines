extends SceneTree
## Integration: actual generated WAVs and acceptance-only playback hooks.

const Audio := preload("res://scripts/asset_audio.gd")
var failures := 0


func _initialize() -> void:
	call_deferred("_verify")


func _check(ok: bool, label: String) -> void:
	print("[ASSET AUDIO] %s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func _has_voice(p: PlayerController, cue: StringName) -> bool:
	var voice := p.get_node_or_null(NodePath("GeneratedAudio_" + String(cue))) as AudioStreamPlayer
	return voice != null and voice.stream is AudioStreamWAV and voice.playing


func _verify() -> void:
	for cue: StringName in Audio.CUES:
		var path := Audio.AUDIO_DIR + String(cue) + ".wav"
		var stream := load(path) as AudioStreamWAV
		_check(stream != null and not stream.stereo and stream.mix_rate == 44100
			and stream.get_length() >= 0.10 and stream.get_length() <= 1.0,
			"generated nonempty mono 44.1 kHz " + String(cue))

	var p: PlayerController = load("res://scenes/player.tscn").instantiate()
	root.add_child(p)
	p.demo_active = true
	_check(not p.spike_burst() and not _has_voice(p, &"burst"), "refused burst stays silent")
	_check(not p.evolve() and not _has_voice(p, &"evolve"), "refused evolution stays silent")
	var mote := Absorbable.new()
	mote.drift = false
	mote.nutrition_value = 30.0
	root.add_child(mote)
	p.demo_interact_held = true
	p._tick_absorb(p.ABSORB_CHANNEL)
	_check(mote.consumed and p.nutrition == 30.0 and _has_voice(p, &"pickup"), "completed mote channel plays pickup")
	_check(p.evolve() and p.evolved and _has_voice(p, &"evolve"), "completed evolution plays cue")
	_check(p.spike_burst() and is_equal_approx(p.energy, 2.0) and _has_voice(p, &"burst"),
		"committed burst plays cue without changing cost")
	_check(p.take_damage(1, Vector2.UP) and p.health == 2 and _has_voice(p, &"damage"),
		"nonlethal hit plays damage")
	_check(not p.take_damage(1, Vector2.UP) and not _has_voice(p, &"death"), "grace rejects hit")
	p._invuln = 0.0
	_check(p.take_damage(2, Vector2.UP) and p.dead and _has_voice(p, &"death"), "lethal hit plays death")
	for child in p.get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	p.queue_free()
	mote.queue_free()
	await create_timer(0.1).timeout
	quit(0 if failures == 0 else 1)
