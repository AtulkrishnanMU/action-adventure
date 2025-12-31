extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var walk: AudioStreamPlayer2D = $walk
@onready var jump: AudioStreamPlayer2D = $jump
@onready var landing: AudioStreamPlayer2D = $landing
@onready var slash: AudioStreamPlayer2D = $slash
@onready var dust_particles: GPUParticles2D = $DustParticles
@onready var landing_dust_particles_right: GPUParticles2D = $LandingDustParticles
@onready var landing_dust_particles_left: GPUParticles2D = $LandingDustParticlesLeft

const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const ParticlesUtil = preload("res://scripts/utils/particles_util.gd")

const SPEED = 600.0
const ROLL_SPEED = 1200.0
const ATTACK_SPEED = 300.0
const JUMP_VELOCITY = -850.0

var FALL_GRAVITY_MULTIPLIER := 1.5
var was_on_floor := false
var is_attacking := false
var attack_alternate := false
var is_rolling := false
var roll_direction := 0
var jump_count := 0
var max_jumps := 2
var jump_dust_timer := 0.0
const JUMP_DUST_DURATION := 0.2

var default_dust_amount: int
var default_landing_right_amount: int
var default_landing_left_amount: int

func _ready():
	default_dust_amount = dust_particles.amount
	default_landing_right_amount = landing_dust_particles_right.amount
	default_landing_left_amount = landing_dust_particles_left.amount
	ParticlesUtil.init_particles(dust_particles, landing_dust_particles_right, landing_dust_particles_left)

func _physics_process(delta: float) -> void:
	
	var on_floor := is_on_floor()

	# LANDING DETECTION
	if on_floor and not was_on_floor:
		AudioUtils.play_with_random_pitch(landing, 0.9, 1.1)
		jump_count = 0  # Reset jump count when landing
		# Create dust burst on landing
		ParticlesUtil.trigger_landing_burst(
			landing_dust_particles_right,
			landing_dust_particles_left,
			abs(velocity.x),
			SPEED,
			default_landing_right_amount,
			default_landing_left_amount
		)

	was_on_floor = on_floor
	
	var moving_right: bool = velocity.x > 1
	var moving_left: bool = velocity.x < -1
	var is_moving_horizontally := moving_right or moving_left
	
	# Update jump dust timer
	jump_dust_timer = ParticlesUtil.update_jump_dust_timer(jump_dust_timer, delta)
	ParticlesUtil.update_continuous_dust(
		dust_particles,
		is_moving_horizontally,
		on_floor,
		jump_dust_timer,
		abs(velocity.x),
		SPEED,
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
	
	# Check if attack animation has finished
	if is_attacking and animated_sprite_2d.animation.begins_with("attack"):
		if animated_sprite_2d.frame == animated_sprite_2d.sprite_frames.get_frame_count(animated_sprite_2d.animation) - 1:
			is_attacking = false
			animated_sprite_2d.animation = "idle"
	
	# Roll logic - works whether horizontal or down is pressed first
	if Input.is_action_pressed("ui_down") and is_on_floor() and not is_rolling and not is_attacking:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction != 0:  # Roll when down is held and horizontal is pressed
			is_rolling = true
			roll_direction = direction
			animated_sprite_2d.animation = "roll"
			animated_sprite_2d.flip_h = direction < 0
	
	# Check if roll animation has finished
	if is_rolling and animated_sprite_2d.animation == "roll":
		if animated_sprite_2d.frame == animated_sprite_2d.sprite_frames.get_frame_count("roll") - 1:
			is_rolling = false
			roll_direction = 0
			animated_sprite_2d.animation = "idle"
	
	if not is_attacking and not is_rolling:
		if (moving_right or moving_left) and is_on_floor():
			animated_sprite_2d.animation = "run"
			if moving_left:
				animated_sprite_2d.flip_h = true
			else:
				animated_sprite_2d.flip_h = false
			if not walk.playing:
				walk.pitch_scale = randf_range(0.9, 1.1)
				walk.play()
		else:
			animated_sprite_2d.animation = "idle"
	
	if not is_on_floor():
		if not is_attacking and not is_rolling:
			animated_sprite_2d.animation = "jump"
		if velocity.y > 0:  # falling
			velocity += get_gravity() * FALL_GRAVITY_MULTIPLIER * delta
		else:  # rising (jumping)
			velocity += get_gravity() * delta

	if Input.is_action_just_pressed("ui_accept") and jump_count < max_jumps and not is_rolling:
		velocity.y = JUMP_VELOCITY
		jump_count += 1
		AudioUtils.play_with_random_pitch(jump, 0.9, 1.1)
		# Start dust trail for jump
		jump_dust_timer = JUMP_DUST_DURATION
		dust_particles.emitting = true

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		var current_speed
		if is_rolling:
			current_speed = ROLL_SPEED
		elif is_attacking:
			current_speed = ATTACK_SPEED
		else:
			current_speed = SPEED
		velocity.x = direction * current_speed
	elif is_rolling:
		# Continue rolling in the stored direction even if keys are released
		velocity.x = roll_direction * ROLL_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
