extends RefCounted

const ParticlesUtil = preload("res://scripts/utils/particles_util.gd")

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
