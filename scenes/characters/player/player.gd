extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk: AudioStreamPlayer2D = $walk
@onready var jump: AudioStreamPlayer2D = $jump
@onready var landing: AudioStreamPlayer2D = $landing
@onready var slash: AudioStreamPlayer2D = $slash
@onready var hit: AudioStreamPlayer2D = $Hit
@onready var hurt: AudioStreamPlayer2D = $Hurt
@onready var death: AudioStreamPlayer2D = $Death
@onready var dust_particles: GPUParticles2D = $DustParticles
@onready var landing_dust_particles_right: GPUParticles2D = $LandingDustParticles
@onready var landing_dust_particles_left: GPUParticles2D = $LandingDustParticlesLeft
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_timer: Timer = $HitboxTimer
@onready var player_area: Area2D = $PlayerArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var left_wall_detector: RayCast2D = $LeftWallDetector
@onready var right_wall_detector: RayCast2D = $RightWallDetector
var hitbox_offset_x: float
var original_hitbox_position: Vector2

const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const ParticlesUtil = preload("res://scripts/utils/particles_util.gd")
const CharacterUtils = preload("res://scripts/utils/character_utils.gd")

# Movement Speeds
@export var speed: float = 600.0
@export var roll_speed: float = 1200.0
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

@export var hitbox_duration: float = 0.1  # Duration in seconds for hitbox to be active

func is_player() -> bool:
	return true

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
		AudioUtils.play_with_random_pitch(hurt, 0.9, 1.1)
	
	# Check if player died
	if current_hp <= 0:
		_handle_player_death()

func _ready():
	# Ensure player only collides with ground, not enemies
	collision_layer = 2  # Layer 2
	collision_mask = 1   # Only check layer 1 (ground)
	default_dust_amount = dust_particles.amount
	default_landing_right_amount = landing_dust_particles_right.amount
	default_landing_left_amount = landing_dust_particles_left.amount
	ParticlesUtil.init_particles(dust_particles, landing_dust_particles_right, landing_dust_particles_left)
	original_hitbox_position = hitbox.position
	hitbox_offset_x = original_hitbox_position.x
	hitbox_collision_shape.disabled = true
	hitbox_timer.one_shot = true
	hitbox_timer.timeout.connect(_on_hitbox_timer_timeout)
	
	# Connect hurtbox signal
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	
	# Initialize UI health
	_update_ui_health()
	
	# Player area initialization

func _on_hitbox_timer_timeout() -> void:
	# Disable hitbox when timer ends
	hitbox_collision_shape.disabled = true

func _physics_process(delta: float) -> void:
	# Don't process anything if dead
	if is_dead:
		return
		
	var on_floor := is_on_floor()
	var direction := Input.get_axis("ui_left", "ui_right")

	# LANDING DETECTION
	if CharacterUtils.is_landing(on_floor, was_on_floor):
		AudioUtils.play_with_random_pitch(landing, 0.9, 1.1)
		jump_count = 0  # Reset jump count when landing
		is_jumping = false  # Reset jumping state when landing
		# Create dust burst on landing
		ParticlesUtil.trigger_landing_burst(
			landing_dust_particles_right,
			landing_dust_particles_left,
			abs(velocity.x),
			attack_speed,
			default_landing_right_amount,
			default_landing_left_amount
		)

	was_on_floor = on_floor
	
	var moving_right: bool = CharacterUtils.is_moving_right(velocity.x)
	var moving_left: bool = CharacterUtils.is_moving_left(velocity.x)
	var is_moving_horizontally := CharacterUtils.is_moving_horizontally(velocity.x)
	
	# Update jump dust timer
	jump_dust_timer = ParticlesUtil.update_jump_dust_timer(jump_dust_timer, delta)
	ParticlesUtil.update_continuous_dust(
		dust_particles,
		is_moving_horizontally,
		on_floor,
		jump_dust_timer,
		abs(velocity.x),
		speed,
		default_dust_amount
	)
	
	if Input.is_action_just_pressed("attack") and not is_attacking and not is_rolling:
		AudioUtils.play_with_random_pitch(slash, 0.9, 1.1)
		if attack_alternate:
			animated_sprite_2d.animation = "attack2"
		else:
			animated_sprite_2d.animation = "attack1"
		attack_alternate = not attack_alternate
		is_attacking = true
		# Set knockback direction and velocity
		knockback_direction = -1.0 if animated_sprite_2d.flip_h else 1.0
		knockback_velocity = attack_knockback
		hitbox_collision_shape.disabled = false
		hitbox_timer.start(hitbox_duration)  # Start timer to disable hitbox after specified duration
	
	# Check if attack animation has finished
	if is_attacking and animated_sprite_2d.animation.begins_with("attack"):
		if CharacterUtils.is_animation_last_frame(animated_sprite_2d):
			is_attacking = false
	
	# Roll logic - works whether horizontal or down is pressed first
	if Input.is_action_pressed("ui_down") and is_on_floor() and not is_rolling and not is_attacking:
		var roll_input_direction := Input.get_axis("ui_left", "ui_right")
		if roll_input_direction != 0:  # Roll when down is held and horizontal is pressed
			is_rolling = true
			roll_direction = int(roll_input_direction)
			animated_sprite_2d.animation = "roll"
			animated_sprite_2d.flip_h = roll_input_direction < 0
	
	# Check if roll animation has finished
	if is_rolling and animated_sprite_2d.animation == "roll":
		if CharacterUtils.is_animation_last_frame(animated_sprite_2d, "roll"):
			is_rolling = false
			roll_direction = 0
			animated_sprite_2d.animation = "idle"
	
	# Handle sprite flipping based on horizontal input (works in air too, and during attacks)
	if direction != 0 and not is_rolling:
		animated_sprite_2d.flip_h = direction < 0
		
	# Handle running animation and sound (only on ground)
	if not is_attacking and not is_rolling:
		if (moving_right or moving_left) and is_on_floor():
			animated_sprite_2d.animation = "run"
			if not walk.playing:
				walk.pitch_scale = randf_range(0.9, 1.1)
				walk.play()
		else:
			animated_sprite_2d.animation = "idle"
	
	if not is_on_floor():
		if not is_attacking and not is_rolling:
			animated_sprite_2d.animation = "jump"
		velocity = CharacterUtils.apply_gravity(velocity, get_gravity(), delta, fall_gravity_multiplier)
		# Apply wall sliding using custom raycast detection with hysteresis
		var is_on_wall_now = is_on_wall_custom()
		
		# Handle wall sliding without hysteresis
		if is_on_wall_now:
			# Reset jump count when touching wall (for wall jumps)
			if jump_count > 0:
				jump_count = 0
				print("Jump count reset by wall contact")
		
		if is_on_wall_now and velocity.y > 0:  # Only when falling, not jumping up
			print("Wall sliding activated - setting velocity.y to: ", wall_slide_speed)
			# Gradually reduce downward velocity to wall slide speed
			velocity.y = wall_slide_speed

	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps and not is_rolling:
		velocity.y = jump_velocity
		jump_count += 1
		is_jumping = true  # Start jumping state
		AudioUtils.play_with_random_pitch(jump, 0.9, 1.1)
		# Start dust trail for jump
		jump_dust_timer = jump_dust_duration
		dust_particles.emitting = true
	
	# Variable jump height: apply extra gravity when jump button is released
	if is_jumping and not Input.is_action_pressed("ui_accept"):
		# Apply stronger gravity to cut the jump short
		velocity.y += get_gravity().y * variable_jump_multiplier * delta
		if velocity.y >= 0:  # Once falling, no longer jumping
			is_jumping = false

	# Apply knockback if active
	if knockback_velocity > 0:
		velocity.x = knockback_direction * knockback_velocity
		knockback_velocity = move_toward(knockback_velocity, 0, speed * delta * 2)
	else:
		# Allow movement input during attacks and rolls
		var current_speed
		if is_rolling:
			current_speed = roll_speed
		else:
			current_speed = speed
		
		if direction != 0:
			velocity.x = direction * current_speed
			# Allow changing direction during attack
			if is_attacking and sign(direction) != sign(velocity.x):
				animated_sprite_2d.flip_h = direction < 0
				# Update hitbox position when direction changes during attack
				CharacterUtils.update_hitbox_position_x(hitbox, original_hitbox_position, animated_sprite_2d.flip_h)
		elif is_rolling:
			# Continue rolling in the stored direction even if keys are released
			velocity.x = roll_direction * roll_speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)

	CharacterUtils.update_hitbox_position_x(hitbox, original_hitbox_position, animated_sprite_2d.flip_h)

	move_and_slide()

func play_hit_sound() -> void:
	"""Play hit sound with random pitch variation"""
	if hit:
		AudioUtils.play_with_random_pitch(hit, 0.9, 1.1)

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
		AudioUtils.play_with_random_pitch(death, 0.8, 1.2)
	
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
	
	# Debug logging with more details
	print("Wall Detection - Left: ", left_colliding, " Right: ", right_colliding, " Result: ", result)
	print("Left raycast pos: ", left_wall_detector.global_position, " target: ", left_wall_detector.target_position)
	print("Right raycast pos: ", right_wall_detector.global_position, " target: ", right_wall_detector.target_position)
	print("Left collision mask: ", left_wall_detector.collision_mask, " Right collision mask: ", right_wall_detector.collision_mask)
	
	if left_colliding:
		print("Left hit collider: ", left_wall_detector.get_collider())
	if right_colliding:
		print("Right hit collider: ", right_wall_detector.get_collider())
	
	return result

func _on_hurtbox_area_entered(area: Area2D) -> void:
	"""Called when enemy hitbox enters player hurtbox"""
	# Check if the entering area is an enemy hitbox (but not our own hitbox)
	if area.collision_layer == 2 and area != hitbox:  # Enemy hitboxes are on layer 2, exclude our own hitbox
		var enemy = area.get_parent()
		var enemy_position = enemy.global_position if enemy else Vector2.ZERO
		
		# Take damage (using 10 damage as default enemy damage)
		take_damage(10, enemy_position)
