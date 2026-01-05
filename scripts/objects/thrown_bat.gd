class_name ThrownBat
extends Area2D

const CharacterUtils = preload("res://scripts/utils/character_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")

const BAT_SPEED = 1200.0
const BAT_RETURN_SPEED = 1400.0
const BAT_TRAVEL_DISTANCE = 600.0
const SPIN_SPEED = 20.0  # Rotations per second

@onready var sprite: Sprite2D = $Sprite2D

var direction: Vector2 = Vector2.RIGHT
var start_position: Vector2
var thrower: Node2D
var rotation_angle: float = 0.0
var damage: int = 25
var spin_sound_player: AudioStreamPlayer2D = null

# State variables
var is_returning: bool = false
var return_timeout: float = 3.0  # 3 seconds timeout for return
var total_flight_time: float = 0.0

# Speed variation variables
var current_speed: float = BAT_SPEED
var min_flight_speed: float = BAT_SPEED * 0.3

# Rotation speed variables
var current_spin_speed: float = 0.0

func _ready() -> void:
	start_position = global_position
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Add to projectiles group
	add_to_group("projectiles")
	
	# Set up collision
	collision_mask = 1  # World/collider layer
	collision_mask |= 16  # Enemy layer (layer 5)

func _physics_process(delta: float) -> void:
	total_flight_time += delta
	
	# Update spin speed
	if total_flight_time < 0.2:
		# Accelerate into spin
		current_spin_speed = min(current_spin_speed + delta * 6, 1.2)
	elif not is_returning:
		# Maintain spin with slight decay
		current_spin_speed = max(current_spin_speed * 0.98, 0.8)
	
	# Apply rotation
	rotation_angle += SPIN_SPEED * current_spin_speed * 2 * PI * delta
	sprite.rotation = rotation_angle
	
	# Check for auto-return
	if total_flight_time >= return_timeout:
		is_returning = true
	
	# Check max distance
	var current_distance = global_position.distance_to(start_position)
	if current_distance >= BAT_TRAVEL_DISTANCE:
		is_returning = true
	
	if is_returning:
		_handle_return(delta)
	else:
		_move_forward(delta)

func _move_forward(delta: float) -> void:
	var move_vec = direction.normalized() * current_speed * delta
	global_position += move_vec

func _handle_return(delta: float) -> void:
	if not thrower or not is_instance_valid(thrower):
		queue_free()
		return
	
	var to_player = thrower.global_position - global_position
	var distance = to_player.length()
	
	if distance <= 40.0:
		_pickup_bat()
		return
	
	# Move towards player
	var move_distance = min(BAT_RETURN_SPEED * delta, distance)
	global_position += to_player.normalized() * move_distance

func _pickup_bat():
	if thrower and is_instance_valid(thrower):
		if thrower.has_method("_on_bat_returned"):
			thrower._on_bat_returned()
	queue_free()

func _on_body_entered(body: Node) -> void:
	# Only handle direct body collisions (not hurtbox areas)
	print("[DEBUG] Bat _on_body_entered: ", body.name, " groups: ", body.get_groups())
	if body == thrower:
		return
	
	# Check if this is an enemy body (not a hurtbox area)
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		print("[DEBUG] Bat hit enemy body: ", body.name)
		body.take_damage(damage, global_position)  # Pass bat position as attacker_position
		CharacterUtils.apply_knockback(body, global_position, 300.0, 0.2)

func _on_area_entered(area: Area2D) -> void:
	# Only process hurtbox areas from enemies
	print("[DEBUG] Bat _on_area_entered: ", area.name, " groups: ", area.get_groups())
	var owner = area.get_parent()
	if owner and owner != thrower:
		# Check if this area is a hurtbox and owner is an enemy
		if area.is_in_group("hurtboxes") and owner.is_in_group("enemies") and owner.has_method("take_damage"):
			print("[DEBUG] Bat hit enemy hurtbox: ", owner.name)
			owner.take_damage(damage, global_position)  # Pass bat position as attacker_position
			CharacterUtils.apply_knockback(owner, global_position, 300.0, 0.2)
