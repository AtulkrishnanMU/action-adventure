extends RefCounted

static func camera_shake(camera: Camera2D, intensity: float, duration: float) -> void:
	if not camera:
		return
	
	var original_position := camera.position
	
	# Create a shake effect using tween
	var tween := camera.create_tween()
	tween.set_parallel(true)
	
	# Shake multiple times for the duration
	var shake_count := int(duration * 30)  # 30 shakes per second
	for i in range(shake_count):
		var delay := float(i) / 30.0
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_callback(func(): camera.position = original_position + offset).set_delay(delay)
	
	# Return to original position at the end
	tween.tween_callback(func(): camera.position = original_position).set_delay(duration)
