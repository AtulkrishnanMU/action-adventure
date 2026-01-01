extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk: AudioStreamPlayer2D = $walk
@onready var jump: AudioStreamPlayer2D = $jump
@onready var landing: AudioStreamPlayer2D = $landing
@onready var slash: AudioStreamPlayer2D = $slash
@onready var hit: AudioStreamPlayer2D = $Hit
@onready var dust_particles: GPUParticles2D = $DustParticles
@onready var landing_dust_particles_right: GPUParticles2D = $LandingDustParticles
@onready var landing_dust_particles_left: GPUParticles2D = $LandingDustParticlesLeft
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_collision_shape: CollisionShape2D = $Hitbox/CollisionShape2D
@onready var hitbox_timer: Timer = $HitboxTimer
@onready var player_area: Area2D = $PlayerArea
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
@export var jump_velocity: float = -850.0
@export var max_jumps: int = 2
@export var fall_gravity_multiplier: float = 1.5

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
var jump_count := 0
var jump_dust_timer := 0.0
var knockback_velocity := 0.0
var knockback_direction := 1.0
var current_hp: int = 100
var max_hp: int = 100

@export var hitbox_duration: float = 0.1  # Duration in seconds for hitbox to be active

func is_player() -> bool:
	return true

func take_damage(amount: int, attacker_position: Vector2 = Vector2.ZERO) -> void:
	current_hp = max(0, current_hp - amount)
	# Apply knockback
	if attacker_position != Vector2.ZERO:
		var knockback_dir = (global_position - attacker_position).normalized()
		velocity = knockback_dir * 500.0
		velocity.y = -200.0  # Add upward force
	# Flash red effect
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color.WHITE, 0.1)

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
	
	# Player area initialization

func _on_hitbox_timer_timeout() -> void:
	# Disable hitbox when timer ends
	hitbox_collision_shape.disabled = true

func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var direction := Input.get_axis("ui_left", "ui_right")

	# LANDING DETECTION
	if CharacterUtils.is_landing(on_floor, was_on_floor):
		AudioUtils.play_with_random_pitch(landing, 0.9, 1.1)
		jump_count = 0  # Reset jump count when landing
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
	
	# Handle sprite flipping based on horizontal input (works in air too)
	if direction != 0 and not is_attacking and not is_rolling:
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

	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps and not is_rolling:
		velocity.y = jump_velocity
		jump_count += 1
		AudioUtils.play_with_random_pitch(jump, 0.9, 1.1)
		# Start dust trail for jump
		jump_dust_timer = jump_dust_duration
		dust_particles.emitting = true

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
