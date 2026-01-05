extends RefCounted

# Camera shake constants
const DEFAULT_SHAKE_INTENSITY: float = 10.0
const DEFAULT_SHAKE_DURATION: float = 0.5

# Pre-calculated shake patterns for performance
enum ShakePattern {
	LIGHT,
	MEDIUM,
	HEAVY,
	EXPLOSIVE
}

# Pre-calculated shake offsets (normalized to intensity = 1.0)
const LIGHT_SHAKE_PATTERN: Array[Vector2] = [
	Vector2(0.3, 0.2), Vector2(-0.2, 0.3), Vector2(0.1, -0.2), Vector2(-0.1, -0.1),
	Vector2(0.2, 0.1), Vector2(-0.3, 0.2), Vector2(0.1, -0.3), Vector2(-0.2, -0.1)
]

const MEDIUM_SHAKE_PATTERN: Array[Vector2] = [
	Vector2(0.7, 0.5), Vector2(-0.5, 0.7), Vector2(0.3, -0.5), Vector2(-0.3, -0.3),
	Vector2(0.5, 0.3), Vector2(-0.7, 0.5), Vector2(0.3, -0.7), Vector2(-0.5, -0.3),
	Vector2(0.4, 0.2), Vector2(-0.2, 0.4), Vector2(0.1, -0.2), Vector2(-0.1, -0.1)
]

const HEAVY_SHAKE_PATTERN: Array[Vector2] = [
	Vector2(1.0, 0.8), Vector2(-0.8, 1.0), Vector2(0.6, -0.8), Vector2(-0.6, -0.6),
	Vector2(0.8, 0.6), Vector2(-1.0, 0.8), Vector2(0.6, -1.0), Vector2(-0.8, -0.6),
	Vector2(0.7, 0.5), Vector2(-0.5, 0.7), Vector2(0.3, -0.5), Vector2(-0.3, -0.3),
	Vector2(0.4, 0.2), Vector2(-0.2, 0.4), Vector2(0.1, -0.2), Vector2(-0.1, -0.1)
]

const EXPLOSIVE_SHAKE_PATTERN: Array[Vector2] = [
	Vector2(1.2, 1.0), Vector2(-1.0, 1.2), Vector2(0.8, -1.0), Vector2(-0.8, -0.8),
	Vector2(1.0, 0.8), Vector2(-1.2, 1.0), Vector2(0.8, -1.2), Vector2(-1.0, -0.8),
	Vector2(0.9, 0.7), Vector2(-0.7, 0.9), Vector2(0.5, -0.7), Vector2(-0.5, -0.5),
	Vector2(0.6, 0.4), Vector2(-0.4, 0.6), Vector2(0.2, -0.4), Vector2(-0.2, -0.2),
	Vector2(0.3, 0.1), Vector2(-0.1, 0.3), Vector2(0.0, -0.1), Vector2(0.0, 0.0)
]

# Performance optimization: cache frequently used patterns
static var _cached_patterns: Dictionary = {}

static func camera_shake(camera: Camera2D, intensity: float, duration: float) -> void:
	if not camera:
		return
	
	# Always use the constants
	intensity = DEFAULT_SHAKE_INTENSITY
	duration = DEFAULT_SHAKE_DURATION
	
	var original_position := camera.position
	
	# Select appropriate shake pattern based on intensity
	var pattern: Array[Vector2]
	if intensity <= 10.0:
		pattern = LIGHT_SHAKE_PATTERN
	elif intensity <= 25.0:
		pattern = MEDIUM_SHAKE_PATTERN
	elif intensity <= 40.0:
		pattern = HEAVY_SHAKE_PATTERN
	else:
		pattern = EXPLOSIVE_SHAKE_PATTERN
	
	# Calculate shake parameters
	var shake_count := pattern.size()
	var step_duration := duration / float(shake_count)
	
	# Create optimized tween with simple interpolation
	var tween := camera.create_tween()
	tween.set_parallel(false)
	
	# Apply pre-calculated shake pattern
	for i in range(shake_count):
		var shake_offset := pattern[i] * intensity
		var fade_factor := 1.0 - (float(i) / float(shake_count) * 0.7)  # Simple fade out
		var final_offset := shake_offset * fade_factor
		
		# Add shake step
		tween.tween_property(camera, "position", original_position + final_offset, step_duration)
	
	# Return to original position
	tween.tween_property(camera, "position", original_position, 0.1)

# Optimized version with pattern selection
static func camera_shake_pattern(camera: Camera2D, pattern: ShakePattern, intensity: float, duration: float) -> void:
	if not camera:
		return
	
	# Always use the constants
	intensity = DEFAULT_SHAKE_INTENSITY
	duration = DEFAULT_SHAKE_DURATION
	
	var original_position := camera.position
	
	# Get the pre-calculated pattern
	var pattern_array: Array[Vector2]
	match pattern:
		ShakePattern.LIGHT:
			pattern_array = LIGHT_SHAKE_PATTERN
		ShakePattern.MEDIUM:
			pattern_array = MEDIUM_SHAKE_PATTERN
		ShakePattern.HEAVY:
			pattern_array = HEAVY_SHAKE_PATTERN
		ShakePattern.EXPLOSIVE:
			pattern_array = EXPLOSIVE_SHAKE_PATTERN
	
	# Calculate shake parameters
	var shake_count := pattern_array.size()
	var step_duration := duration / float(shake_count)
	
	# Create optimized tween
	var tween := camera.create_tween()
	tween.set_parallel(false)
	
	# Apply pattern with intensity scaling
	for i in range(shake_count):
		var shake_offset := pattern_array[i] * intensity
		var fade_factor := 1.0 - (float(i) / float(shake_count) * 0.7)
		var final_offset := shake_offset * fade_factor
		
		tween.tween_property(camera, "position", original_position + final_offset, step_duration)
	
	# Return to original position
	tween.tween_property(camera, "position", original_position, 0.1)

# Simplified one-shot shake for performance
static func camera_shake_simple(camera: Camera2D, intensity: float, duration: float) -> void:
	if not camera:
		return
	
	# Always use the constants
	intensity = DEFAULT_SHAKE_INTENSITY
	duration = DEFAULT_SHAKE_DURATION
	
	# Reduce intensity and duration by 40%
	duration *= 0.7
	
	# Get or create tween
	var tween = camera.get_tree().create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	# Stop any existing shake
	tween.stop()
	
	# Store original position
	var original_position = camera.position
	
	# Generate random offset (reduced vertical shake)
	var offset = Vector2(
		randf_range(-1, 1) * intensity * 0.7,  # Reduced horizontal shake
		randf_range(-1, 1) * intensity * 0.3    # Even less vertical shake
	)
	
	# Apply gentler shake
	tween.tween_property(camera, "position", original_position + offset, duration * 0.2)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	# Smoother return to original position
	tween.tween_property(camera, "position", original_position, duration * 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

# Helper function to get the best shake pattern for intensity
static func get_optimal_pattern(intensity: float) -> ShakePattern:
	if intensity <= 10.0:
		return ShakePattern.LIGHT
	elif intensity <= 25.0:
		return ShakePattern.MEDIUM
	elif intensity <= 40.0:
		return ShakePattern.HEAVY
	else:
		return ShakePattern.EXPLOSIVE

# Ultra-performance shake for frequent calls (like footsteps)
static func camera_shake_micro(camera: Camera2D, intensity: float) -> void:
	if not camera:
		return
	
	# Reduce micro shake intensity by 60%
	intensity *= 0.4
	
	# Use a simpler, more performant shake for frequent events
	var tween = camera.get_tree().create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	
	# Even more subtle shake for micro events
	var offset = Vector2(
		randf_range(-1, 1) * intensity * 0.05,  # Reduced from 0.1
		randf_range(-1, 1) * intensity * 0.02   # Reduced from 0.05
	)
	
	var original_pos = camera.position
	tween.tween_property(camera, "position", original_pos + offset, 0.03)  # Faster
	tween.tween_property(camera, "position", original_pos, 0.07)  # Faster return
	tween.tween_callback(tween.queue_free)
