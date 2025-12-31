extends Node

static func play_with_random_pitch(player, min_pitch := 0.9, max_pitch := 1.1) -> void:
	if not player:
		return
	player.pitch_scale = randf_range(min_pitch, max_pitch)
	player.play()
