extends RefCounted

const BLOOD_SPRITES = [
	"res://sprites/effects/blood/blood1.png",
	"res://sprites/effects/blood/blood2.png"
]

static func _scaled_amount(speed: float, base_speed: float, default_amount: int, min_amount: int = 1, max_amount: int = 10_000) -> int:
	if default_amount <= 0:
		return 0
	if base_speed <= 0.0:
		return clampi(default_amount, min_amount, max_amount)
	var scale := (speed / base_speed)/2
	var amt := int(round(float(default_amount) * scale))
	return clampi(amt, min_amount, max_amount)

static func create_blood_splash(position: Vector2, direction: Vector2, amount: int = 10) -> void:
	for i in range(amount):
		var blood_particle = _create_blood_particle(position, direction)
		if blood_particle:
			# Add to scene tree
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.current_scene:
				scene_tree.current_scene.add_child(blood_particle)
				# Auto-remove after animation
				_remove_particle_after_time(blood_particle, 2.0)

static func _create_blood_particle(position: Vector2, direction: Vector2) -> Sprite2D:
	var blood_sprite = Sprite2D.new()
	
	# Random blood sprite
	var random_blood = BLOOD_SPRITES[randi() % BLOOD_SPRITES.size()]
	var texture = load(random_blood)
	if not texture:
		return null
	
	blood_sprite.texture = texture
	blood_sprite.position = position
	
	# Random scale and rotation
	var scale_factor = randf_range(0.3, 0.8)
	blood_sprite.scale = Vector2(scale_factor, scale_factor)
	blood_sprite.rotation = randf() * PI * 2
	
	# Add physics for particle movement with gravity
	var tween = blood_sprite.create_tween()
	
	# Random velocity in the general direction of the hit
	var spread_angle = PI / 3  # 60 degree spread
	var random_angle = direction.angle() + randf_range(-spread_angle/2, spread_angle/2)
	var horizontal_velocity = Vector2.from_angle(random_angle) * randf_range(80, 200)
	var gravity_velocity = Vector2(0, 300)  # Downward gravity
	
	# Calculate final position with gravity arc
	var duration = 0.8
	var final_position = position + horizontal_velocity * duration + gravity_velocity * duration * duration * 0.5
	
	# Animate the particle with arc motion
	blood_sprite.modulate = Color.WHITE
	tween.parallel().tween_property(blood_sprite, "position", final_position, duration).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(blood_sprite, "modulate:a", 0.0, 1.5).set_delay(duration).set_ease(Tween.EASE_IN)
	
	return blood_sprite

static func _remove_particle_after_time(particle: Node, time: float) -> void:
	await Engine.get_main_loop().create_timer(time).timeout
	if is_instance_valid(particle):
		particle.queue_free()

static func init_particles(dust_particles: GPUParticles2D, landing_right: GPUParticles2D, landing_left: GPUParticles2D) -> void:
	dust_particles.emitting = false
	landing_right.emitting = false
	landing_left.emitting = false

static func trigger_landing_burst(
		landing_right: GPUParticles2D,
		landing_left: GPUParticles2D,
		speed: float,
		base_speed: float,
		default_amount_right: int,
		default_amount_left: int
	) -> void:
	landing_right.amount = _scaled_amount(speed, base_speed, default_amount_right)
	landing_left.amount = _scaled_amount(speed, base_speed, default_amount_left)
	landing_right.restart()
	landing_right.emitting = true
	landing_left.restart()
	landing_left.emitting = true

static func update_jump_dust_timer(current_timer: float, delta: float) -> float:
	if current_timer <= 0.0:
		return 0.0
	current_timer -= delta
	if current_timer <= 0.0:
		return 0.0
	return current_timer

static func update_continuous_dust(
		dust_particles: GPUParticles2D,
		is_moving_horizontally: bool,
		on_floor: bool,
		jump_dust_timer: float,
		speed: float,
		base_speed: float,
		default_amount: int
	) -> void:
	var should_emit := (is_moving_horizontally and on_floor) or (jump_dust_timer > 0.0)
	if should_emit:
		var target_amount := _scaled_amount(speed, base_speed, default_amount)
		if not dust_particles.emitting:
			dust_particles.amount = target_amount
		else:
			# Avoid decreasing amount while emitting; it can cull existing particles abruptly.
			if target_amount > dust_particles.amount:
				dust_particles.amount = target_amount
		dust_particles.emitting = true
	else:
		if dust_particles.emitting:
			dust_particles.emitting = false
