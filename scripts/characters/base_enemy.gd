class_name BaseEnemy
extends CharacterBody2D

const CameraUtils = preload("res://scripts/utils/camera_utils.gd")

## The gravity applied to the enemy (pixels/s^2)
@export var gravity: float = 2000.0
## Maximum falling speed (pixels/s)
@export var max_fall_speed: float = 1000.0
## Maximum health points
@export var max_hp: int = 10
## Damage taken from each player hit
@export var damage_per_hit: int = 10
## Knockback force when hit
@export var knockback_force: float = 300.0
## Knockback force for fatal hit (larger knockback)
@export var fatal_knockback_force: float = 600.0
## Knockback friction/damping factor
@export var knockback_friction: float = 0.9
## Movement speed when following player
@export var move_speed: float = 200.0
## Detection range for player
@export var detection_range: float = 300.0
## Attack range
@export var attack_range: float = 50.0
## Attack cooldown time
@export var attack_cooldown: float = 1.0

@onready var hurtbox = $Hurtbox
@onready var animated_sprite = $AnimatedSprite2D if has_node("AnimatedSprite2D") else null
@onready var hitbox = $Hitbox if has_node("Hitbox") else null
@onready var hitbox_collision_shape = $Hitbox/CollisionShape2D if has_node("Hitbox/CollisionShape2D") else null

var current_hp: int = 0  # Will be set in _ready() after max_hp is set
var player: CharacterBody2D = null
var is_attacking: bool = false
var attack_cooldown_timer: float = 0.0
var can_attack: bool = true
var attack_alternate: bool = false  # For alternating between attack animations

func _ready() -> void:
	current_hp = max_hp  # Set current_hp after max_hp is set in child's _ready()
	# Ensure enemy only collides with ground, not player
	collision_layer = 16  # Layer 5
	collision_mask = 1    # Only check layer 1 (ground)
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)
		if hitbox_collision_shape:
			hitbox_collision_shape.disabled = true
	# Find the player in the scene
	_find_player()

func _find_player() -> void:
	var scene_tree = Engine.get_main_loop() as SceneTree
	if scene_tree and scene_tree.current_scene:
		# Look for player in the current scene
		var players = scene_tree.current_scene.find_children("*", "CharacterBody2D", true, false)
		for p in players:
			if p.has_method("is_player") or p.name.to_lower().contains("player"):
				player = p
				break

func _physics_process(delta: float) -> void:
	# Update attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
		can_attack = attack_cooldown_timer <= 0
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)
	
	# Apply knockback friction
	if abs(velocity.x) > 1:
		velocity.x *= knockback_friction
	else:
		velocity.x = 0
	
	# AI behavior
	if not is_attacking and current_hp > 0:
		_update_ai_behavior()
	
	# Check if attack animation has finished
	if is_attacking and animated_sprite and (animated_sprite.animation.begins_with("attack")):
		const CharacterUtils = preload("res://scripts/utils/character_utils.gd")
		if CharacterUtils.is_animation_last_frame(animated_sprite, animated_sprite.animation):
			_finish_attack()
	
	# Apply movement
	move_and_slide()

func _finish_attack() -> void:
	print("Finishing attack")
	is_attacking = false
	# Disable hitbox
	if hitbox_collision_shape:
		hitbox_collision_shape.disabled = true
		print("Hitbox disabled")

func _update_ai_behavior() -> void:
	if not player:
		_find_player()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Debug output
	if Engine.get_process_frames() % 60 == 0:  # Print once per second
		print("Enemy AI - Distance to player: ", distance_to_player, " Detection range: ", detection_range, " Attack range: ", attack_range)
		print("Can attack: ", can_attack, " Is attacking: ", is_attacking)
	
	# Check if player is in detection range
	if distance_to_player <= detection_range:
		# Face the player
		if player.global_position.x < global_position.x:
			animated_sprite.flip_h = true
		else:
			animated_sprite.flip_h = false
		
		# Check if in attack range
		if distance_to_player <= attack_range:
			if can_attack and not is_attacking:
				print("In attack range! Distance: ", distance_to_player, " <= ", attack_range)
				_start_attack()
			else:
				# In attack range but can't attack (cooldown or already attacking)
				print("In attack range but cannot attack - cooldown: ", not can_attack, " attacking: ", is_attacking)
				velocity.x = 0
				# Play idle animation when waiting for cooldown or between attacks
				if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
					animated_sprite.animation = "idle"
		elif not is_attacking:  # Only move if not currently attacking
			# Move towards player
			_move_towards_player()
		else:
			print("Cannot move - is attacking")
			# Stop movement and play idle when attacking or on cooldown
			velocity.x = 0
			if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
				animated_sprite.animation = "idle"
	else:
		# Player not detected, play idle
		velocity.x = 0
		if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.animation = "idle"

func _move_towards_player() -> void:
	if not player:
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity.x = direction.x * move_speed
	
	# Play run animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("run"):
		animated_sprite.animation = "run"

func _start_attack() -> void:
	if not can_attack or is_attacking:
		return
	
	# Don't attack if being knocked back (has significant velocity)
	if abs(velocity.x) > 50:
		print("Cannot attack - being knocked back")
		return
	
	print("Starting attack! Distance: ", global_position.distance_to(player.global_position) if player else "no player")
	is_attacking = true
	can_attack = false
	attack_cooldown_timer = attack_cooldown
	
	# Stop movement when attacking
	velocity.x = 0
	
	# Choose attack animation randomly
	var attack_animations = []
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("attack"):
			attack_animations.append("attack")
		if animated_sprite.sprite_frames.has_animation("attack2"):
			attack_animations.append("attack2")
		if animated_sprite.sprite_frames.has_animation("attack3"):
			attack_animations.append("attack3")
	
	# Randomly select an attack animation
	var chosen_attack = "attack"  # Default fallback
	if attack_animations.size() > 0:
		chosen_attack = attack_animations[randi() % attack_animations.size()]
	
	print("Playing attack animation: ", chosen_attack)
	
	# Play the chosen attack animation
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation(chosen_attack):
		animated_sprite.animation = chosen_attack
	else:
		print("Attack animation '", chosen_attack, "' not found")
	
	# Enable hitbox
	if hitbox_collision_shape:
		hitbox_collision_shape.disabled = false
		print("Hitbox enabled")

func _on_hitbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_area"):
		# Hit the player
		var player_node = area.get_parent()
		if player_node and player_node.has_method("take_damage"):
			player_node.take_damage(1, global_position)

## Called when the enemy takes damage
func take_damage(amount: int = damage_per_hit, attacker_position: Vector2 = Vector2.ZERO) -> void:
	var was_alive = current_hp > 0
	current_hp = max(0, current_hp - amount)
	_on_damage_taken(attacker_position)
	
	if current_hp <= 0 and was_alive:
		_die_with_knockback()

## Called when the enemy dies with knockback effect
func _die_with_knockback() -> void:
	# Disable hurtbox to prevent further hits
	if has_node("Hurtbox"):
		$Hurtbox.set_deferred("monitoring", false)
	
	# Play death animation immediately during knockback
	if is_instance_valid(animated_sprite) and animated_sprite.has_method("play"):
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
	
	# Wait a moment for knockback to be visible, then finish death sequence
	await get_tree().create_timer(0.5).timeout
	_die()

## Called when the enemy dies
func _die() -> void:
	# Stop all movement
	velocity = Vector2.ZERO
	set_physics_process(false)  # Disable physics processing
	
	# Disable collision shape now that knockback is complete
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	
	# Create fade out effect (death animation is already playing)
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await fade_tween.finished
	
	# Remove the enemy from the scene
	queue_free()

## Called whenever the enemy takes damage
## Override in child classes to customize damage behavior
func _on_damage_taken(attacker_position: Vector2 = Vector2.ZERO) -> void:
	# Camera shake when enemy takes damage
	var camera := get_viewport().get_camera_2d()
	if camera:
		var shake_intensity = 20.0 if current_hp > 0 else 30.0  # Stronger shake for fatal hit
		var shake_duration = 0.3 if current_hp > 0 else 0.5  # Longer shake for fatal hit
		CameraUtils.camera_shake(camera, shake_intensity, shake_duration)
	
	# Create blood splash effect
	if attacker_position != Vector2.ZERO:
		const CharacterUtils = preload("res://scripts/utils/character_utils.gd")
		var blood_amount = 5 if current_hp > 0 else 8  # More blood for fatal hit
		CharacterUtils.create_blood_splash(global_position, attacker_position, blood_amount)
	
	# Create a tween for visual feedback when damaged
	var tween = create_tween()
	
	# Only try to tween if we have a valid node
	if is_instance_valid(animated_sprite):
		tween.tween_property(animated_sprite, "modulate", Color(1, 0.5, 0.5, 1.0), 0.1)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.1)
	
	# Apply knockback effect
	if current_hp > 0:
		_apply_knockback(attacker_position, knockback_force)
	else:
		# Apply larger knockback for fatal hit
		_apply_knockback(attacker_position, fatal_knockback_force)

## Apply knockback force in the direction away from attacker
func _apply_knockback(attacker_position: Vector2, force: float) -> void:
	if attacker_position == Vector2.ZERO:
		# Fallback to old logic if no attacker position provided
		var current_scale = animated_sprite.scale.x if animated_sprite.has_method("get_scale") else 1.0
		var knockback_direction = -1 if current_scale > 0 else 1
		velocity.x = knockback_direction * force
	else:
		# Calculate knockback direction away from attacker
		var knockback_direction = (global_position - attacker_position).normalized()
		velocity.x = knockback_direction.x * force
		# Add some upward force for better visual effect
		velocity.y = knockback_direction.y * force * 0.5 - abs(force) * 0.3

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var attacker = area.get_parent()
		var attacker_position = attacker.global_position if attacker else Vector2.ZERO
		
		# Play hit sound on player when hitting enemy
		if attacker and attacker.has_method("play_hit_sound"):
			attacker.play_hit_sound()
		
		take_damage(damage_per_hit, attacker_position)
