extends RefCounted

const ParticlesUtil = preload("res://scripts/utils/particles_util.gd")
const CameraUtils = preload("res://scripts/utils/camera_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")

# Health and damage constants
const HEALTH_HIGH_COLOR = Color(0.2, 0.8, 0.2, 1)  # Green for high health (>50%)
const HEALTH_MEDIUM_COLOR = Color(0.8, 0.8, 0.2, 1)  # Yellow for medium health (<50%)
const HEALTH_LOW_COLOR = Color(0.8, 0.2, 0.2, 1)  # Red for low health (<20%)
const HEALTH_MEDIUM_THRESHOLD = 0.5  # Below this percentage = yellow
const HEALTH_LOW_THRESHOLD = 0.2   # Below this percentage = red

static func is_landing(on_floor: bool, was_on_floor: bool) -> bool:
	return on_floor and not was_on_floor

static func is_moving_right(velocity_x: float, deadzone: float = 1.0) -> bool:
	return velocity_x > deadzone

static func is_moving_left(velocity_x: float, deadzone: float = 1.0) -> bool:
	return velocity_x < -deadzone

static func is_moving_horizontally(velocity_x: float, deadzone: float = 1.0) -> bool:
	return is_moving_right(velocity_x, deadzone) or is_moving_left(velocity_x, deadzone)

static func apply_gravity(velocity: Vector2, gravity: Vector2, delta: float, fall_gravity_multiplier: float = 1.0) -> Vector2:
	if velocity.y > 0.0:
		return velocity + gravity * fall_gravity_multiplier * delta
	return velocity + gravity * delta

static func is_animation_last_frame(sprite: AnimatedSprite2D, animation: String = "") -> bool:
	if not sprite:
		return false
	var anim := animation
	if anim == "":
		anim = sprite.animation
	if not sprite.sprite_frames:
		return false
	var frame_count := sprite.sprite_frames.get_frame_count(anim)
	if frame_count <= 0:
		return false
	return sprite.frame >= frame_count - 1

static func update_hitbox_position_x(
	hitbox: Node2D,
	original_position: Vector2,
	flip_h: bool
) -> void:
	if not hitbox:
		return

	var x: float = original_position.x

	hitbox.position = Vector2(
		x - 60 if flip_h else x,
		original_position.y
	)

static func create_blood_splash(character_position: Vector2, attacker_position: Vector2, amount: int = 10) -> void:
	print("Creating blood splash at: ", character_position, " from attacker: ", attacker_position)
	var direction = (character_position - attacker_position).normalized()
	
	# Create blood splash using the new system
	var blood_splash_scene = preload("res://scenes/effects/blood/blood_splash.tscn")
	var blood_splash = blood_splash_scene.instantiate()
	
	if blood_splash:
		print("Blood splash instance created successfully")
		# Add to scene tree
		var scene_tree = Engine.get_main_loop() as SceneTree
		if scene_tree and scene_tree.current_scene:
			scene_tree.current_scene.add_child(blood_splash)
			# Move blood splash to back of scene tree to respect z_index ordering
			scene_tree.current_scene.move_child(blood_splash, 0)
			
			# Set position and direction
			blood_splash.global_position = character_position
			blood_splash.set_direction(direction)
			print("Blood splash added to scene")
		else:
			print("Failed to get current scene")
	else:
		print("Failed to instantiate blood splash")

# Damage and death methods
static func handle_damage_effects(
	character: Node2D,
	current_hp: int,
	max_hp: int,
	attacker_position: Vector2 = Vector2.ZERO,
	camera_shake_intensity: float = 20.0,
	camera_shake_duration: float = 0.3,
	fatal_shake_intensity: float = 30.0,
	fatal_shake_duration: float = 0.5
) -> void:
	"""Handle generic damage effects including camera shake, blood, and sounds"""
	# Camera shake when character takes damage
	var camera := character.get_viewport().get_camera_2d()
	if camera:
		var shake_intensity = camera_shake_intensity if current_hp > 0 else fatal_shake_intensity
		var shake_duration = camera_shake_duration if current_hp > 0 else fatal_shake_duration
		CameraUtils.camera_shake(camera, shake_intensity, shake_duration)
	
	# Create blood splash effect
	if attacker_position != Vector2.ZERO:
		var blood_amount = 5 if current_hp > 0 else 8  # More blood for fatal hit
		create_blood_splash(character.global_position, attacker_position, blood_amount)

static func handle_character_death(
	character: Node2D,
	animated_sprite: AnimatedSprite2D = null,
	death_animation: String = "death",
	knockback_force: float = 600.0,
	fade_duration: float = 0.5
) -> void:
	"""Handle generic character death with knockback, animation, and removal"""
	# Disable hurtbox to prevent further hits
	if character.has_node("Hurtbox"):
		character.get_node("Hurtbox").set_deferred("monitoring", false)
	
	# Play death animation immediately during knockback
	if animated_sprite and animated_sprite.has_method("play"):
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(death_animation):
			animated_sprite.play(death_animation)
	
	# Wait a moment for knockback to be visible, then finish death sequence
	await character.get_tree().create_timer(0.5).timeout
	_complete_character_removal(character, animated_sprite, fade_duration)

static func _complete_character_removal(
	character: Node2D,
	animated_sprite: AnimatedSprite2D = null,
	fade_duration: float = 0.5
) -> void:
	"""Complete the character removal process"""
	# Stop all movement
	if character.has_method("set_physics_process"):
		character.set_physics_process(false)
	
	# Disable collision shape now that knockback is complete
	if character.has_node("CollisionShape2D"):
		character.get_node("CollisionShape2D").set_deferred("disabled", true)
	
	# Create fade out effect (death animation is already playing)
	var fade_tween = character.create_tween()
	fade_tween.tween_property(character, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await fade_tween.finished
	
	# Remove the character from the scene
	character.queue_free()

static func apply_knockback(
	character: Node2D,
	attacker_position: Vector2,
	force: float,
	upward_force_multiplier: float = 0.3
) -> void:
	"""Apply knockback force away from attacker"""
	if attacker_position == Vector2.ZERO:
		# Fallback to old logic if no attacker position provided
		var current_scale = 1.0
		if character.has_node("AnimatedSprite2D"):
			var sprite = character.get_node("AnimatedSprite2D")
			current_scale = sprite.scale.x if sprite.has_method("get_scale") else 1.0
		var knockback_direction = -1 if current_scale > 0 else 1
		if character.has_method("set"):
			character.set("velocity.x", knockback_direction * force)
	else:
		# Calculate knockback direction away from attacker
		var knockback_direction = (character.global_position - attacker_position).normalized()
		if character.has_method("set"):
			character.set("velocity.x", knockback_direction.x * force)
			character.set("velocity.y", knockback_direction.y * force * 0.5 - abs(force) * upward_force_multiplier)

static func play_damage_audio(
	character: Node2D,
	current_hp: int,
	hurt_audio_node: AudioStreamPlayer2D = null,
	death_audio_node: AudioStreamPlayer2D = null
) -> void:
	"""Play appropriate hurt or death sound"""
	# Play hurt sound if character is still alive
	if current_hp > 0 and hurt_audio_node:
		AudioUtils.play_with_random_pitch(hurt_audio_node, 0.9, 1.1)
	# Play death sound if character dies
	elif current_hp <= 0 and death_audio_node:
		AudioUtils.play_with_random_pitch(death_audio_node, 0.8, 1.2)
