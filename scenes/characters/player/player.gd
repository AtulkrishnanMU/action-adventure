extends CharacterBody2D
# Core frequently accessed nodes - cached for performance
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var left_wall_detector: RayCast2D = $LeftWallDetector
@onready var right_wall_detector: RayCast2D = $RightWallDetector

# Audio nodes - properly cached with @onready for performance
@onready var walk: AudioStreamPlayer2D = $walk
@onready var jump: AudioStreamPlayer2D = $jump
@onready var landing: AudioStreamPlayer2D = $landing
@onready var slash: AudioStreamPlayer2D = $slash
@onready var hit: AudioStreamPlayer2D = $Hit
@onready var hurt: AudioStreamPlayer2D = $Hurt
@onready var death: AudioStreamPlayer2D = $Death
@onready var dash_attack: AudioStreamPlayer2D = $DashAttack

# Lazy-loaded particle nodes - cached when first accessed for performance
var dust_particles: GPUParticles2D
var landing_dust_particles_right: GPUParticles2D
var landing_dust_particles_left: GPUParticles2D
var hitbox_timer: Timer
var player_area: Area2D
var dash_trail_sprite: Sprite2D

# Performance optimization: cache frequently used positions and calculations
var cached_jump_dust_position: Vector2 = Vector2(-1.4800978, 61.9203925)
var cached_wall_contact_point: Vector2 = Vector2.ZERO
var wall_contact_update_timer: float = 0.0
const WALL_CONTACT_UPDATE_INTERVAL: float = 0.05  # Update wall contact 20 times per second

# Audio performance optimizations
var walk_audio_timer: float = 0.0
const WALK_AUDIO_CHECK_INTERVAL: float = 0.1  # Check walk audio 10 times per second
var cached_walk_pitch: float = 1.0
var walk_pitch_update_timer: float = 0.0
const WALK_PITCH_UPDATE_INTERVAL: float = 0.2  # Update walk pitch 5 times per second

# Pre-cached random pitch values for performance
var cached_random_pitches: Array[float] = []
const CACHED_PITCH_COUNT: int = 10
var pitch_cache_index: int = 0
var dash_trails: Array[Sprite2D] = []  # Store multiple trail sprites
var hitbox_offset_x: float
var original_hitbox_position: Vector2

# Dash trail pooling system
var trail_pool: Array[Sprite2D] = []  # Pool of reusable trail sprites
var max_pool_size: int = 20  # Maximum number of trails to keep in pool
var max_active_trails: int = 6  # Reduced from 10 for better performance
var pool_parent: Node2D  # Parent node for pooled trails

const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const ParticlesUtil = preload("res://scripts/utils/particles_util.gd")
const CharacterUtils = preload("res://scripts/utils/character_utils.gd")

# Movement Speeds
@export var speed: float = 600.0
@export var roll_speed: float = 1500.0
@export var attack_speed: float = 300.0
@export var attack_knockback: float = 400.0  # Knockback force when attacking

# Jump Settings
@export var jump_velocity: float = -1000.0  # Decreased from -1200.0
@export var max_jumps: int = 2
@export var fall_gravity_multiplier: float = 1.3  # Increased from 1.2
@export var variable_jump_multiplier: float = 2.5  # Decreased from 3.0

# Wall Slide Settings
@export var wall_slide_speed: float = 100.0  # Downward speed when sliding on walls
@export var wall_slide_acceleration: float = 500.0  # How quickly to reach slide speed

# Visual Effects
@export var jump_dust_duration: float = 0.2
@export var default_dust_amount: int = 0
@export var default_landing_right_amount: int = 0
@export var default_landing_left_amount: int = 0
@export var max_roll_duration: float = 1.0
@export var wall_slide_dust_amount: int = 10  # Amount of dust for wall sliding

# Dash Settings
@export var dash_distance: float = 300.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 1.0

# Squash & Stretch
@export var jump_squash_scale := Vector2(0.85, 1.15)
@export var jump_stretch_scale := Vector2(1.1, 0.9)
@export var land_squash_scale := Vector2(1.2, 0.8)
@export var squash_duration := 0.08

var squash_tween: Tween
var original_sprite_scale: Vector2

# Internal State
var was_on_floor := false
var is_attacking := false
var attack_alternate := false
var is_rolling := false
var roll_direction := 0
var is_dead := false
var jump_count := 0
var jump_dust_timer := 0.0
var knockback_velocity := 0.0
var knockback_direction := 1.0
var current_hp: int = 100
var max_hp: int = 100
var is_jumping := false  # Track if currently jumping upwards
var is_wall_jumping := false  # Track if currently wall jumping
var wall_jump_cooldown_timer := 0.0
@export var wall_jump_cooldown_duration: float = 0.5
var roll_timer: float = 0.0
var roll_input_locked: bool = false
var wall_jump_direction_locked: bool = false
var is_dashing := false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction := Vector2.ZERO
var dash_trail_timer: float = 0.0
var trail_creation_timer: float = 0.0  # Additional timer for performance optimization

# Bat throwing variables
var has_bat: bool = true
var bat_in_air: bool = false

# Particle optimization variables
var cached_contact_points: Array = []
var contact_update_timer: float = 0.0
@export var contact_update_interval: float = 0.05  # Update contact points 20 times per second max (optimized from 0.1)
@export var dash_trail_start_interval: float = 0.02  # Reduced from 0.01 for better performance
@export var dash_trail_end_interval: float = 0.01   # Reduced from 0.005 for better performance
@export var min_trail_creation_interval: float = 0.015  # Minimum time between trail creations

@export var hitbox_duration: float = 0.1  # Duration in seconds for hitbox to be active
@export var dash_damage_multiplier: float = 2.0  # Damage multiplier during dash

func _exit_tree() -> void:
	# Clean up trail pool when player is removed
	if pool_parent:
		pool_parent.queue_free()
	# Clean up any active trails
	for trail in dash_trails:
		if is_instance_valid(trail):
			trail.queue_free()
	dash_trails.clear()
	trail_pool.clear()

func is_player() -> bool:
	return true

# Lazy initialization helper methods
func _get_dust_particles() -> GPUParticles2D:
	if not dust_particles:
		dust_particles = $DustParticles
	return dust_particles

func _get_landing_dust_particles_right() -> GPUParticles2D:
	if not landing_dust_particles_right:
		landing_dust_particles_right = $LandingDustParticles
	return landing_dust_particles_right

func _get_landing_dust_particles_left() -> GPUParticles2D:
	if not landing_dust_particles_left:
		landing_dust_particles_left = $LandingDustParticlesLeft
	return landing_dust_particles_left

func _get_hitbox_timer() -> Timer:
	if not hitbox_timer:
		hitbox_timer = $HitboxTimer
	return hitbox_timer

func _get_player_area() -> Area2D:
	if not player_area:
		player_area = $PlayerArea
	return player_area

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return  # Don't take damage if already dead
		
	current_hp = max(0, current_hp - amount)
	
	# Handle damage effects using CharacterUtils
	CharacterUtils.handle_damage_effects(
		self,
		current_hp,
		max_hp,
		attacker_position,
		15.0,  # Regular shake intensity (less than enemy)
		0.2,   # Regular shake duration
		25.0,  # Fatal shake intensity
		0.4    # Fatal shake duration
	)
	
	# Apply knockback using player's own system (same as small enemy)
	if attacker_position != Vector2.ZERO:
		var knockback_dir = (global_position - attacker_position).normalized()
		knockback_direction = knockback_dir.x
	else:
		# Fallback: knockback based on facing direction
		knockback_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
	knockback_velocity = 300.0  # Same as small enemy's knockback_force
	
	# Update UI health bar
	_update_ui_health()
	
	# Flash red effect
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.1)
	
	# Play hurt sound
	if hurt:
		_play_audio_optimized(hurt, 0.9, 1.1)
	
	# Check if player died
	if current_hp <= 0:
		_handle_player_death()

func _ready():
	# Ensure player only collides with ground, not enemies
	collision_layer = 2  # Layer 2
	collision_mask = 1   # Only check layer 1 (ground)
	add_to_group("player")  # Add to player group for enemy detection
	
	# Initialize particle systems lazily
	var dust = _get_dust_particles()
	var landing_right = _get_landing_dust_particles_right()
	var landing_left = _get_landing_dust_particles_left()
	default_dust_amount = dust.amount
	default_landing_right_amount = landing_right.amount
	default_landing_left_amount = landing_left.amount
	ParticlesUtil.init_particles(dust, landing_right, landing_left)
	
	original_hitbox_position = hitbox.position
	hitbox_offset_x = original_hitbox_position.x
	hitbox_collision_shape.disabled = true
	
	# Initialize hitbox timer lazily
	var timer = _get_hitbox_timer()
	timer.one_shot = true
	timer.timeout.connect(_on_hitbox_timer_timeout)
	
	# Connect hurtbox signal
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	# Initialize UI health
	_update_ui_health()
	
	# Store original sprite scale for squash & stretch
	original_sprite_scale = animated_sprite_2d.scale
	
	# Set up dash trail
	_setup_dash_trail()
	
	# Initialize dash trail pool
	_setup_trail_pool()
	
	# Set dust particles to render below player
	_setup_dust_layers()
	
	# Initialize audio performance optimizations
	_initialize_audio_cache()
	
	# Player area initialization

func _setup_dust_layers() -> void:
	# Set dust particles to render below player using z-index
	var dust = _get_dust_particles()
	var landing_left = _get_landing_dust_particles_left()
	var landing_right = _get_landing_dust_particles_right()
	dust.z_index = -1
	landing_left.z_index = -1
	landing_right.z_index = -1
	
	# Alternative: Use rendering layers if needed
	# dust_particles.render_layer = 1
	# landing_dust_particles_left.render_layer = 1
	# landing_dust_particles_right.render_layer = 1

func _initialize_audio_cache() -> void:
	"""Initialize pre-cached random pitch values for performance"""
	cached_random_pitches.clear()
	for i in range(CACHED_PITCH_COUNT):
		cached_random_pitches.append(randf_range(0.8, 1.2))
	pitch_cache_index = 0

func _play_audio_optimized(audio_player: AudioStreamPlayer2D, min_pitch: float = 0.9, max_pitch: float = 1.1) -> void:
	"""Optimized audio playing with cached pitch values"""
	if not audio_player:
		return
	
	# Use cached pitch value and cycle through cache
	audio_player.pitch_scale = cached_random_pitches[pitch_cache_index]
	pitch_cache_index = (pitch_cache_index + 1) % CACHED_PITCH_COUNT
	audio_player.play()

func _setup_trail_pool() -> void:
	# Defer the entire pool setup to avoid scene tree blocking issues
	_setup_pool_deferred.call_deferred()

func _setup_pool_deferred() -> void:
	# Create a parent node for pooled trails to keep scene organized
	pool_parent = Node2D.new()  # Use Node2D to support visibility
	pool_parent.name = "DashTrailPool"
	get_tree().current_scene.add_child(pool_parent)
	pool_parent.visible = false  # Hide pooled trails by default

func _get_pooled_trail() -> Sprite2D:
	# Ensure pool parent is ready before using
	if not pool_parent or not pool_parent.is_inside_tree():
		return _create_new_trail_sprite()
		
	# Get a trail from pool or create new one if pool is empty
	if trail_pool.size() > 0:
		var trail = trail_pool.pop_back()
		if trail.get_parent():
			trail.get_parent().remove_child(trail)
		return trail
	else:
		# Create new trail if pool is empty
		return _create_new_trail_sprite()

func _create_new_trail_sprite() -> Sprite2D:
	var trail = Sprite2D.new()
	
	# Apply shader material
	var shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://shaders/dash_trail.gdshader")
	trail.material = shader_material
	trail.z_index = -1  # Behind main sprite
	
	return trail

func _return_trail_to_pool(trail: Sprite2D) -> void:
	# Ensure pool parent is ready before using
	if not pool_parent or not pool_parent.is_inside_tree():
		# Pool not ready, just destroy the trail
		trail.queue_free()
		return
		
	# Return trail to pool if not at max capacity
	if trail_pool.size() < max_pool_size:
		# Reset trail properties
		trail.visible = false
		trail.modulate = Color.WHITE
		if trail.material and trail.material is ShaderMaterial:
			trail.material.set_shader_parameter("fade_alpha", 1.0)
		
		# Remove from current parent and add to pool
		if trail.get_parent():
			trail.get_parent().remove_child(trail)
		pool_parent.add_child(trail)
		trail_pool.append(trail)
	else:
		# Destroy trail if pool is full
		trail.queue_free()

func _setup_dash_trail() -> void:
	# Create main trail sprite for copying
	dash_trail_sprite = Sprite2D.new()
	add_child(dash_trail_sprite)
	
	# Set up dash trail sprite
	dash_trail_sprite.modulate = Color.WHITE
	dash_trail_sprite.z_index = -1  # Behind main sprite
	
	# Load and apply shader
	var shader_material = ShaderMaterial.new()
	shader_material.shader = load("res://shaders/dash_trail.gdshader")
	dash_trail_sprite.material = shader_material
	
	# Initially hide the trail
	dash_trail_sprite.visible = false

func _create_dash_trail() -> void:
	if not dash_trail_sprite:
		return
		
	# Limit the number of active trails to prevent performance issues
	if dash_trails.size() >= max_active_trails:
		# Remove the oldest trail to make room
		var oldest_trail = dash_trails[0]
		if is_instance_valid(oldest_trail):
			_return_trail_to_pool(oldest_trail)
		dash_trails.erase(oldest_trail)
		
	# Get trail from pool instead of creating new instance
	var trail_instance = _get_pooled_trail()
	get_tree().current_scene.add_child(trail_instance)  # Add to scene root
	dash_trails.append(trail_instance)
	
	# Update trail sprite to match current animation frame
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.animation != "":
		var frame = animated_sprite_2d.frame
		var texture = animated_sprite_2d.sprite_frames.get_frame_texture(animated_sprite_2d.animation, frame)
		if texture:
			trail_instance.texture = texture
	
	# Copy position, scale, and flip at creation time
	var creation_position = global_position - (dash_direction * 25.0)  # Offset behind player
	trail_instance.global_position = creation_position
	# Apply combined scale from player root and animated sprite for correct size
	trail_instance.scale = scale * animated_sprite_2d.scale
	trail_instance.flip_h = animated_sprite_2d.flip_h
	trail_instance.modulate = Color.WHITE
	trail_instance.z_index = -1  # Behind main sprite
	
	# Reset shader material and set initial fade alpha
	if trail_instance.material and trail_instance.material is ShaderMaterial:
		trail_instance.material.set_shader_parameter("fade_alpha", 1.0)  # Start at full opacity
	
	# Make trail visible and fade out from full opacity
	trail_instance.visible = true
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(alpha): 
		if trail_instance.material and trail_instance.material is ShaderMaterial:
			trail_instance.material.set_shader_parameter("fade_alpha", alpha)
	, 1.0, 0.0, 0.5)  # Fade out over 0.5 seconds
	tween.tween_callback(func(): 
		_return_trail_to_pool(trail_instance)  # Return to pool instead of queue_free
		dash_trails.erase(trail_instance)
	).set_delay(0.5)

func _get_floor_contact_points() -> Array:
	var contact_points = []
	# Use get_slide_collision_count to get actual floor contact points
	if is_on_floor():
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			# Check if collision is with floor (normal pointing up)
			if collision.get_normal().y < -0.5:  # Floor has upward normal
				contact_points.append(collision.get_position())
	
	# Fallback: estimate contact points at player's feet using collision shape
	if contact_points.is_empty():
		# Use the bottom edge of the collision shape for more accurate positioning
		var collision_shape_bottom = global_position + Vector2(0, 61.9203925)  # Bottom edge of collision shape
		contact_points.append(collision_shape_bottom + Vector2(-10, 0))
		contact_points.append(collision_shape_bottom + Vector2(10, 0))
	
	return contact_points

func _get_wall_contact_point() -> Vector2:
	if left_wall_detector and left_wall_detector.is_colliding():
		return left_wall_detector.get_collision_point()
	elif right_wall_detector and right_wall_detector.is_colliding():
		return right_wall_detector.get_collision_point()
	
	# Fallback: check slide collisions for wall contact
	if is_on_wall():
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			# Check if collision is with wall (normal pointing sideways)
			if abs(collision.get_normal().x) > 0.5:  # Wall has sideways normal
				return collision.get_position()
	
	return Vector2.ZERO

func _play_jump_squash() -> void:
	if squash_tween:
		squash_tween.kill()

	animated_sprite_2d.scale = original_sprite_scale
	squash_tween = create_tween()
	squash_tween.set_trans(Tween.TRANS_SINE)
	squash_tween.set_ease(Tween.EASE_OUT)

	# Squish → Stretch → Normal
	squash_tween.tween_property(
		animated_sprite_2d,
		"scale",
		original_sprite_scale * jump_squash_scale,
		squash_duration
	)
	squash_tween.tween_property(
		animated_sprite_2d,
		"scale",
		original_sprite_scale * jump_stretch_scale,
		squash_duration
	)
	squash_tween.tween_property(
		animated_sprite_2d,
		"scale",
		original_sprite_scale,
		squash_duration
	)


func _play_land_squash() -> void:
	if squash_tween:
		squash_tween.kill()

	animated_sprite_2d.scale = original_sprite_scale
	squash_tween = create_tween()
	squash_tween.set_trans(Tween.TRANS_SINE)
	squash_tween.set_ease(Tween.EASE_OUT)

	# Squash → Normal
	squash_tween.tween_property(
		animated_sprite_2d,
		"scale",
		original_sprite_scale * land_squash_scale,
		squash_duration
	)
	squash_tween.tween_property(
		animated_sprite_2d,
		"scale",
		original_sprite_scale,
		squash_duration
	)

func _on_hitbox_timer_timeout() -> void:
	# Disable hitbox when timer ends
	hitbox_collision_shape.disabled = true

func _physics_process(delta: float) -> void:
	# Don't process anything if dead
	if is_dead:
		return
	
	# Debug: Track animation state changes
	var prev_animation = animated_sprite_2d.animation
		
	# Update cached contact points less frequently for performance
	contact_update_timer += delta
	if contact_update_timer >= contact_update_interval:
		cached_contact_points = _get_floor_contact_points()
		contact_update_timer = 0.0
	
	# Update wall contact point less frequently
	wall_contact_update_timer += delta
	if wall_contact_update_timer >= WALL_CONTACT_UPDATE_INTERVAL:
		cached_wall_contact_point = _get_wall_contact_point()
		wall_contact_update_timer = 0.0
	
	# Update audio timers for performance optimization
	walk_audio_timer += delta
	walk_pitch_update_timer += delta
		
	# Performance optimization: cache frequently used calculations
	var on_floor := is_on_floor()
	var direction := Input.get_axis("ui_left", "ui_right")
	var moving_right: bool = direction > 0
	var moving_left: bool = direction < 0
	var is_moving_horizontally := direction != 0
	var is_on_wall_now := is_on_wall_custom()  # Cache wall detection

	# LANDING DETECTION
	if CharacterUtils.is_landing(on_floor, was_on_floor):
		_play_audio_optimized(landing, 0.9, 1.1)
		jump_count = 0  # Reset jump count when landing
		is_jumping = false  # Reset jumping state when landing
		
		_play_land_squash()
		
		# Create dust burst on landing at actual contact points
		var fresh_contact_points = _get_floor_contact_points()
		if fresh_contact_points.size() > 0:
			# Position both landing dust particles at the same contact point (or middle point)
			var landing_left = _get_landing_dust_particles_left()
			var landing_right = _get_landing_dust_particles_right()
			
			# Determine the emission position
			var emission_position: Vector2
			if fresh_contact_points.size() >= 2:
				# Use middle point between two contact points
				emission_position = (fresh_contact_points[0] + fresh_contact_points[1]) / 2.0
			else:
				# Use the single contact point
				emission_position = fresh_contact_points[0]
			
			# Position both particles at the same emission point
			landing_left.global_position = emission_position
			landing_right.global_position = emission_position
			
			# Emit both particles in opposite directions
			landing_left.restart()
			landing_left.emitting = true
			landing_right.restart()
			landing_right.emitting = true
		else:
			# Fallback to original logic if no contact points detected
			ParticlesUtil.trigger_landing_burst(
				_get_landing_dust_particles_right(),
				_get_landing_dust_particles_left(),
				abs(velocity.x),
				attack_speed,
				default_landing_right_amount,
				default_landing_left_amount
			)

	was_on_floor = on_floor
	
	
	# Update jump dust timer
	jump_dust_timer = ParticlesUtil.update_jump_dust_timer(jump_dust_timer, delta)
	# Update continuous dust at contact points
	var should_emit := (is_moving_horizontally and on_floor) or (jump_dust_timer > 0.0)
	if should_emit:
		if jump_dust_timer > 0.0:
			# Use player center for jump dust (collision shape position) - use cached position
			var dust = _get_dust_particles()
			dust.position = cached_jump_dust_position
			dust.emitting = true
		else:
			# Use cached floor contact points for movement dust
			if cached_contact_points.size() > 0:
				for point in cached_contact_points:
					var dust = _get_dust_particles()
					dust.global_position = point
					var target_amount := ParticlesUtil._scaled_amount(abs(velocity.x), speed, default_dust_amount)
					if not dust.emitting:
						dust.amount = target_amount
					else:
						if target_amount > dust.amount:
							dust.amount = target_amount
					dust.emitting = true
			else:
				# Fallback to original logic
				ParticlesUtil.update_continuous_dust(
					_get_dust_particles(),
					is_moving_horizontally,
					on_floor,
					jump_dust_timer,
					abs(velocity.x),
					speed,
					default_dust_amount
				)
	else:
		# Stop dust emission if not moving on floor and not jumping and not wall sliding
		var dust = _get_dust_particles()
		if dust.emitting and not is_on_wall_custom():
			dust.emitting = false
	
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling and not bat_in_air:
		print("[DEBUG] Attack initiated - is_on_floor: ", is_on_floor(), " is_on_wall: ", is_on_wall(), " current animation: ", animated_sprite_2d.animation)
		_play_audio_optimized(slash, 0.9, 1.1)
		if attack_alternate:
			animated_sprite_2d.animation = "attack2"
		else:
			animated_sprite_2d.animation = "attack1"
		print("[DEBUG] Attack animation set to: ", animated_sprite_2d.animation)
		attack_alternate = not attack_alternate
		is_attacking = true
		# Set knockback direction and velocity
		knockback_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
		knockback_velocity = attack_knockback
		hitbox_collision_shape.disabled = false
		var timer = _get_hitbox_timer()
		timer.start(hitbox_duration)  # Start timer to disable hitbox after specified duration
	
	# Dash input handling
	if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0 and not is_rolling and not is_attacking and not bat_in_air:
		_start_dash()
	
	# Bat throwing input handling
	if Input.is_action_just_pressed("throw_bat") and has_bat and not bat_in_air and not is_rolling and not is_attacking:
		_throw_bat()
	
	# Check if attack animation has finished
	if is_attacking and animated_sprite_2d.animation.begins_with("attack"):
		if CharacterUtils.is_animation_last_frame(animated_sprite_2d):
			print("[DEBUG] Attack animation finished - is_on_floor: ", is_on_floor(), " is_on_wall: ", is_on_wall(), " current animation: ", animated_sprite_2d.animation)
			is_attacking = false
	
	# Roll logic - works whether horizontal or down is pressed first
	var down_held := Input.is_action_pressed("ui_down")
	var roll_input_direction := Input.get_axis("ui_left", "ui_right")
	
	# Start roll ONLY if input is not locked
	if down_held and roll_input_direction != 0 and is_on_floor() and not is_rolling and not is_attacking and not roll_input_locked:
		is_rolling = true
		roll_direction = int(roll_input_direction)
		roll_timer = 0.0
		roll_input_locked = true

		var target_roll_animation = "roll_without_bat" if bat_in_air else "roll"
		animated_sprite_2d.animation = target_roll_animation
		animated_sprite_2d.flip_h = roll_direction < 0
	
	# Stop roll ONLY if player hits a wall
	if is_rolling and is_on_wall():
		is_rolling = false
		roll_direction = 0
		animated_sprite_2d.animation = "idle"

	# Update roll timer and auto-stop after 3 seconds
	if is_rolling:
		roll_timer += delta

		if roll_timer >= max_roll_duration:
			is_rolling = false
			roll_direction = 0
			animated_sprite_2d.animation = "idle"
	
	# Reset roll input lock and stop roll once player releases the roll combo
	if roll_input_locked:
		if not Input.is_action_pressed("ui_down") or Input.get_axis("ui_left", "ui_right") == 0:
			roll_input_locked = false
			# Stop roll if player releases input mid-roll
			if is_rolling:
				is_rolling = false
				roll_direction = 0
				animated_sprite_2d.animation = "idle"

	# Handle sprite flipping based on horizontal input (works in air too, and during attacks)
	if direction != 0 and not is_rolling:
		animated_sprite_2d.flip_h = direction < 0
		
	# Handle wall jump animation - HIGHEST PRIORITY
	if is_wall_jumping:
		# Check if roll animation has finished
		if CharacterUtils.is_animation_last_frame(animated_sprite_2d, "roll"):
			is_wall_jumping = false
			# Switch back to jump animation after wall jump roll completes
			if not is_on_floor():
				animated_sprite_2d.animation = "jump"
	
	# Update wall jump cooldown timer
	if wall_jump_cooldown_timer > 0:
		wall_jump_cooldown_timer -= delta
	
	# Reset wall jump direction lock once player releases and presses direction again or lands on floor
	if wall_jump_direction_locked:
		var current_direction := Input.get_axis("ui_left", "ui_right")
		if current_direction == 0 or is_on_floor():  # Player released direction OR landed on floor
			wall_jump_direction_locked = false
	
	# Handle running animation and sound (only on ground) - use cached direction and audio optimization
	if not is_attacking and not is_rolling and not is_wall_jumping and not is_dashing:
		if is_moving_horizontally and on_floor:
			if not bat_in_air:
				if animated_sprite_2d.animation != "run":
					print("[DEBUG] Setting run animation - is_on_floor: ", on_floor, " is_moving_horizontally: ", is_moving_horizontally)
				animated_sprite_2d.animation = "run"
			else:
				if animated_sprite_2d.animation != "run_without_bat":
					print("[DEBUG] Setting run_without_bat animation - is_on_floor: ", on_floor, " is_moving_horizontally: ", is_moving_horizontally)
					animated_sprite_2d.animation = "run_without_bat"
			# Optimized walking audio with reduced frequency checks
			if walk_audio_timer >= WALK_AUDIO_CHECK_INTERVAL:
				walk_audio_timer = 0.0
				if not walk.playing:
					# Update cached pitch less frequently using pre-cached values
					if walk_pitch_update_timer >= WALK_PITCH_UPDATE_INTERVAL:
						walk_pitch_update_timer = 0.0
						cached_walk_pitch = cached_random_pitches[pitch_cache_index]
						pitch_cache_index = (pitch_cache_index + 1) % CACHED_PITCH_COUNT
					walk.pitch_scale = cached_walk_pitch
					walk.play()
		else:
			if not bat_in_air:
				if animated_sprite_2d.animation != "idle":
					print("[DEBUG] Setting idle animation - is_on_floor: ", on_floor, " is_moving_horizontally: ", is_moving_horizontally, " previous animation: ", animated_sprite_2d.animation)
				animated_sprite_2d.animation = "idle"
			else:
				if animated_sprite_2d.animation != "idle_without_bat":
					print("[DEBUG] Setting idle_without_bat animation - is_on_floor: ", on_floor, " is_moving_horizontally: ", is_moving_horizontally, " previous animation: ", animated_sprite_2d.animation)
					animated_sprite_2d.animation = "idle_without_bat"
			# Stop walking audio when not moving (check less frequently)
			if walk_audio_timer >= WALK_AUDIO_CHECK_INTERVAL and walk.playing:
				walk.stop()
	
	if not is_on_floor():
		if not is_attacking and not is_rolling and not is_wall_jumping and not is_dashing:
			if is_on_wall_now and velocity.y > 0:  # Only when falling, not jumping up
				var target_wall_slide_animation = "wall_slide_without_bat" if bat_in_air else "wall_slide"
				if animated_sprite_2d.animation != target_wall_slide_animation:
					print("[DEBUG] Setting ", target_wall_slide_animation, " animation - is_attacking: ", is_attacking, " velocity.y: ", velocity.y)
				animated_sprite_2d.animation = target_wall_slide_animation
				# Face away from wall when sliding
				if left_wall_detector.is_colliding():
					animated_sprite_2d.flip_h = false  # Face right when wall is on left
				elif right_wall_detector.is_colliding():
					animated_sprite_2d.flip_h = true   # Face left when wall is on right
			else:
				var target_jump_animation = "jump_without_bat" if bat_in_air else "jump"
				if animated_sprite_2d.animation != target_jump_animation and not animated_sprite_2d.animation.begins_with("attack"):
					print("[DEBUG] Setting ", target_jump_animation, " animation - is_attacking: ", is_attacking, " velocity.y: ", velocity.y, " is_on_wall: ", is_on_wall())
				animated_sprite_2d.animation = target_jump_animation
	velocity = CharacterUtils.apply_gravity(velocity, get_gravity(), delta, fall_gravity_multiplier)

	# Apply wall sliding using cached wall detection
	
	# Handle wall sliding without hysteresis
	if is_on_wall_now:
		# Reset jump count when touching wall (for wall jumps)
		if jump_count > 0:
			jump_count = 0
	
	if is_on_wall_now and velocity.y > 0 and not is_on_floor():  # Only when sliding down wall, not when touching floor
		# Gradually reduce downward velocity to wall slide speed
		velocity.y = wall_slide_speed
		
		# Emit continuous wall sliding dust at cached contact point
		if cached_wall_contact_point != Vector2.ZERO:
			var dust = _get_dust_particles()
			dust.global_position = cached_wall_contact_point
			dust.amount = wall_slide_dust_amount
			dust.emitting = true
	else:
		# Stop wall dust when not actively sliding down wall
		var dust = _get_dust_particles()
		if dust.emitting and not ((is_moving_horizontally and on_floor) or jump_dust_timer > 0.0):
			dust.emitting = false

	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps:
		# Check if player was wall-sliding before jump
		var was_wall_sliding = is_on_wall_custom()
		
		# If jumping during roll, preserve roll momentum and convert to jump
		if is_rolling:
			# Convert roll momentum to jump velocity
			velocity.x = roll_direction * roll_speed
			velocity.y = jump_velocity
			is_rolling = false  # Exit roll state
			roll_direction = 0
			roll_timer = 0.0
			roll_input_locked = false
		else:
			velocity.y = jump_velocity
		
		jump_count += 1
		is_jumping = true  # Start jumping state
		_play_audio_optimized(jump, 0.9, 1.1)
		# Start dust trail for jump at player center (using cached position)
		jump_dust_timer = jump_dust_duration
		var dust = _get_dust_particles()
		dust.position = cached_jump_dust_position
		dust.emitting = true
		
		_play_jump_squash()
		
		# Wall jump: automatically jump away from wall if was wall-sliding
		if was_wall_sliding:
			var wall_jump_dir = get_wall_jump_direction()
			if wall_jump_dir != 0:
				velocity.x = wall_jump_dir * speed * 2.5  # Strong wall jump force
				is_wall_jumping = true
				wall_jump_cooldown_timer = wall_jump_cooldown_duration
				wall_jump_direction_locked = true  # Lock direction input after wall jump
				var target_roll_animation = "roll_without_bat" if bat_in_air else "roll"
				animated_sprite_2d.animation = target_roll_animation
				animated_sprite_2d.flip_h = wall_jump_dir < 0  # Face away from wall
				animated_sprite_2d.play()
	
	# Variable jump height: apply extra gravity when jump button is released
	if is_jumping and not Input.is_action_pressed("ui_accept"):
		# Apply stronger gravity to cut the jump short
		velocity.y += get_gravity().y * variable_jump_multiplier * delta
		if velocity.y >= 0:  # Once falling, no longer jumping
			is_jumping = false

	# Update dash cooldown timer
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	# Handle dash movement
	if is_dashing:
		_update_dash(delta)
	elif knockback_velocity > 0:
		velocity.x = knockback_direction * knockback_velocity
		knockback_velocity = move_toward(knockback_velocity, 0, speed * delta * 2)
	else:
		# Allow movement input during attacks and rolls
		var current_speed
		if is_rolling:
			current_speed = roll_speed
		else:
			current_speed = speed
		
		if direction != 0 and not is_wall_jumping and wall_jump_cooldown_timer <= 0 and not wall_jump_direction_locked:
			velocity.x = direction * current_speed
			# Allow changing direction during attack
			if is_attacking and sign(direction) != sign(velocity.x):
				animated_sprite_2d.flip_h = direction < 0
				# Update hitbox position when direction changes during attack
				CharacterUtils.update_hitbox_position_x(hitbox, original_hitbox_position, animated_sprite_2d.flip_h)
		elif is_rolling:
			# Continue rolling in the stored direction even if keys are released
			velocity.x = roll_direction * roll_speed
		elif not is_wall_jumping:
			velocity.x = move_toward(velocity.x, 0, speed)

	CharacterUtils.update_hitbox_position_x(hitbox, original_hitbox_position, animated_sprite_2d.flip_h)

	# Debug: Log animation changes
	if prev_animation != animated_sprite_2d.animation:
		print("[DEBUG] Animation changed from: ", prev_animation, " to: ", animated_sprite_2d.animation, " | is_attacking: ", is_attacking, " is_on_floor: ", is_on_floor(), " is_on_wall: ", is_on_wall())

	move_and_slide()

func play_hit_sound() -> void:
	"""Play hit sound with optimized cached pitch variation"""
	_play_audio_optimized(hit, 0.9, 1.1)

func _update_ui_health() -> void:
	"""Update the UI health bar with current health values"""
	var ui = get_tree().get_first_node_in_group("ui")
	if ui and ui.has_method("update_health"):
		ui.update_health(current_hp, max_hp)

func _handle_player_death() -> void:
	"""Handle player death"""
	is_dead = true
	
	# Play death sound
	if death:
		_play_audio_optimized(death, 0.8, 1.2)
	
	# Apply death knockback using player's own system (same as small enemy's fatal knockback)
	# Use a position behind the player for dramatic backward knockback
	var knockback_source = global_position + Vector2(-100 if animated_sprite_2d.flip_h else 100, 0)
	var knockback_dir = (global_position - knockback_source).normalized()
	knockback_direction = knockback_dir.x
	knockback_velocity = 600.0  # Same as small enemy's fatal_knockback_force
	
	# Disable hitbox safely (deferred to avoid physics collision issues)
	if hitbox_collision_shape:
		hitbox_collision_shape.set_deferred("disabled", true)
	
	# Play death animation
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation("death"):
		animated_sprite_2d.animation = "death"
		animated_sprite_2d.play()
		
		# Wait a moment for knockback to be visible, then wait for death animation
		await get_tree().create_timer(0.3).timeout
		
		# Now disable all controls after knockback has been applied
		set_physics_process(false)
		set_process(false)
		
		# Wait for death animation to finish
		await animated_sprite_2d.animation_finished
		
		# Just stop at last frame of death animation, no fade
		# Player remains visible for game over screen

func is_on_wall_custom() -> bool:
	"""Custom wall detection using raycasts on both sides"""
	var left_colliding = left_wall_detector.is_colliding()
	var right_colliding = right_wall_detector.is_colliding()
	var result = left_colliding or right_colliding
	
	return result

func get_wall_jump_direction() -> int:
	"""Returns the direction to jump away from wall: 1 for right, -1 for left, 0 for no wall"""
	var left_colliding = left_wall_detector.is_colliding()
	var right_colliding = right_wall_detector.is_colliding()
	
	if left_colliding and not right_colliding:
		return 1  # Jump right when touching left wall
	elif right_colliding and not left_colliding:
		return -1  # Jump left when touching right wall
	else:
		return 0  # No clear wall direction or touching both walls

func _on_hurtbox_area_entered(area: Area2D) -> void:
	"""Called when enemy hitbox enters player hurtbox"""
	# Check if the entering area is an enemy hitbox (but not our own hitbox)
	# Player is invulnerable during rolls
	if area.collision_layer == 2 and area != hitbox and not is_rolling:  # Enemy hitboxes are on layer 2, exclude our own hitbox and check not rolling
		var enemy = area.get_parent()
		var enemy_position = enemy.global_position if enemy else Vector2.ZERO
		
		# Take damage (using 10 damage as default enemy damage)
		take_damage(10, enemy_position)

func _start_dash() -> void:
	# Play dash attack sound
	_play_audio_optimized(dash_attack, 0.9, 1.1)
	
	# Get dash direction from input or facing direction
	var input_dir = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	).normalized()
	
	if input_dir != Vector2.ZERO:
		dash_direction = input_dir
	else:
		# Default to facing direction if no input
		dash_direction = Vector2(-1.0, 0.0) if animated_sprite_2d.flip_h else Vector2(1.0, 0.0)
	
	# Start dash
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_trail_timer = 0.0  # Reset trail timer
	trail_creation_timer = 0.0  # Reset trail creation timer
	
	# Play random attack animation for dash
	var attack_animations = ["attack1", "attack2"]
	var random_attack = attack_animations[randi() % attack_animations.size()]
	animated_sprite_2d.animation = random_attack
	
	# Enable hitbox during dash
	hitbox_collision_shape.disabled = false
	var timer = _get_hitbox_timer()
	timer.start(dash_duration)  # Disable hitbox after dash ends
	
	# Set dash damage flag
	set_meta("is_dashing", true)
	set_meta("dash_damage_multiplier", dash_damage_multiplier)
	
	# Set knockback direction for dash attack
	knockback_direction = 1.0 if dash_direction.x > 0 else -1.0
	knockback_velocity = attack_knockback * 1.5  # Stronger knockback for dash
	
	# Create dash dust effect - use cached position
	var dust = _get_dust_particles()
	dust.position = cached_jump_dust_position
	dust.amount = 12  # Reduced from 15 for performance
	dust.emitting = true
	
	# Create initial dash trail
	_create_dash_trail()

func _get_current_trail_interval() -> float:
	# Calculate progress through dash (0.0 = start, 1.0 = end)
	var dash_progress = 1.0 - (dash_timer / dash_duration)
	
	# Linear interpolation from start interval to end interval
	return lerp(dash_trail_start_interval, dash_trail_end_interval, dash_progress)

func _update_dash(delta: float) -> void:
	dash_timer -= delta
	dash_trail_timer -= delta
	trail_creation_timer += delta  # Update trail creation timer
	
	if dash_timer <= 0.0:
		# End dash
		is_dashing = false
		velocity = Vector2.ZERO  # Stop momentum after dash
		# Hitbox is already disabled by timer
		# Clear dash damage flag
		set_meta("is_dashing", false)
		remove_meta("dash_damage_multiplier")
		# Reset animation to idle after dash
		animated_sprite_2d.animation = "idle"
		return
	
	# Optimized trail creation with minimum interval enforcement
	if dash_trail_timer <= 0.0 and trail_creation_timer >= min_trail_creation_interval:
		_create_dash_trail()
		dash_trail_timer = _get_current_trail_interval()
		trail_creation_timer = 0.0  # Reset creation timer after creating trail
	
	# Calculate dash speed to cover distance in duration
	var dash_speed = dash_distance / dash_duration
	
	# Apply dash velocity
	velocity = dash_direction * dash_speed
	
	# Override gravity during dash
	# This makes the dash feel more responsive and predictable
	
	# Update sprite facing based on dash direction
	if dash_direction.x != 0:
		animated_sprite_2d.flip_h = dash_direction.x < 0
	
	# Update hitbox position to follow dash direction
	if dash_direction.x != 0:
		hitbox.position.x = original_hitbox_position.x + (dash_direction.x * 30)
	else:
		hitbox.position.x = original_hitbox_position.x
	
	# You could add dash animation here if you have one
	# animated_sprite_2d.animation = "dash"

func _throw_bat() -> void:
	"""Throw the bat in the facing direction"""
	if not has_bat or bat_in_air:
		return
	
	# Create bat instance
	var bat_scene = preload("res://scenes/objects/thrown_bat.tscn")
	var bat = bat_scene.instantiate()
	
	# Set bat properties
	bat.thrower = self
	bat.global_position = global_position
	
	# Set direction based on facing direction
	bat.direction = Vector2.RIGHT
	if animated_sprite_2d.flip_h:
		bat.direction = Vector2.LEFT
	
	# Add bat to scene
	get_tree().current_scene.add_child(bat)
	
	# Update player state
	has_bat = false
	bat_in_air = true
	
	print("[DEBUG] Bat thrown - direction: ", bat.direction)

func _on_bat_returned() -> void:
	"""Called when the bat returns to the player"""
	has_bat = true
	bat_in_air = false
	
	print("[DEBUG] Bat returned to player")
	
	# Update animation immediately if needed
	if is_on_floor():
		var is_moving = Input.get_axis("ui_left", "ui_right") != 0
		if is_moving:
			animated_sprite_2d.animation = "run"
		else:
			animated_sprite_2d.animation = "idle"
