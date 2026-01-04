extends Node2D

const CameraUtils = preload("res://scripts/utils/camera_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const RNGUtils = preload("res://scripts/utils/rng_utils.gd")

@onready var sprite = $Sprite2D
@onready var hurtbox = $Hurtbox
@onready var collision_shape = $StaticBody2D/CollisionShape2D  # Reference the collision shape under StaticBody2D
@onready var crate_hit_sound = $CrateHit
@onready var crate_break_sound = $CrateBreak

# Crate textures
const CRATE_TEXTURE: Texture2D = preload("res://sprites/objects/crate/crate.png")
const CRATE_DAMAGE1_TEXTURE: Texture2D = preload("res://sprites/objects/crate/crate-damage1.png")
const CRATE_DAMAGE2_TEXTURE: Texture2D = preload("res://sprites/objects/crate/crate-damage2.png")
const CRATE_BROKEN_PIECE_TEXTURE: Texture2D = preload("res://sprites/objects/crate/crate-broken-piece.png")

# Damage states
enum DamageState {
	INTACT,
	DAMAGE1,
	DAMAGE2,
	BROKEN
}

# Piece pooling system
static var piece_pool: Array[Sprite2D] = []
static var max_piece_pool_size: int = 50
static var piece_pool_parent: Node2D

var current_state = DamageState.INTACT
var hits_taken = 0

func _ready():
	# Set initial texture
	sprite.texture = CRATE_TEXTURE
	# Initialize piece pool with deferred call to avoid setup conflicts
	_setup_piece_pool.call_deferred()

# Piece pooling methods
static func _setup_piece_pool() -> void:
	if piece_pool.size() > 0:
		return  # Pool already initialized
	
	# Create pool parent
	if not piece_pool_parent:
		piece_pool_parent = Node2D.new()
		piece_pool_parent.name = "CratePiecePool"
		# Add to scene tree with deferred call
		var scene_tree = Engine.get_main_loop() as SceneTree
		if scene_tree and scene_tree.current_scene:
			scene_tree.current_scene.add_child.call_deferred(piece_pool_parent)
			piece_pool_parent.visible = false
	
	# Pre-allocate pieces with deferred calls to avoid setup conflicts
	for i in range(max_piece_pool_size):
		var piece = Sprite2D.new()
		piece.texture = preload("res://sprites/objects/crate/crate-broken-piece.png")
		piece_pool.append(piece)
	
	# Add all pieces to parent in a deferred call
	_add_pieces_to_pool_parent.call_deferred()

static func _add_pieces_to_pool_parent() -> void:
	"""Helper function to add pieces to pool parent after setup"""
	if not piece_pool_parent:
		return
	
	for piece in piece_pool:
		if piece and not piece.get_parent():
			piece_pool_parent.add_child(piece)
			piece.visible = false

static func _get_pooled_piece() -> Sprite2D:
	_setup_piece_pool()  # Ensure pool exists
	
	if piece_pool.size() > 0:
		var piece = piece_pool.pop_back()
		if piece and is_instance_valid(piece):
			# Remove from pool parent
			if piece.get_parent():
				piece.get_parent().remove_child(piece)
			piece.visible = true
			return piece
	# Pool exhausted, create new piece
	return Sprite2D.new()

static func _return_piece_to_pool(piece: Sprite2D) -> void:
	if piece and is_instance_valid(piece) and piece_pool.size() < max_piece_pool_size:
		piece.visible = false
		if piece_pool_parent:
			if piece.get_parent():
				piece.get_parent().remove_child(piece)
			piece_pool_parent.add_child(piece)
			piece_pool.append(piece)
	else:
		# Destroy piece if pool is full
		if piece and is_instance_valid(piece):
			piece.queue_free()

func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_hitbox"):
		# Check if this is a dash attack
		var player = area.get_parent()
		var is_dash_attack = player.get_meta("is_dashing", false)
		
		if is_dash_attack:
			# Instant break for dash attacks
			_instant_break()
		else:
			take_damage()

func take_damage():
	hits_taken += 1
	
	match current_state:
		DamageState.INTACT:
			current_state = DamageState.DAMAGE1
			sprite.texture = CRATE_DAMAGE1_TEXTURE
			# Add hit effect
			_hit_effect()
			
		DamageState.DAMAGE1:
			current_state = DamageState.DAMAGE2
			sprite.texture = CRATE_DAMAGE2_TEXTURE
			# Add hit effect
			_hit_effect()
			
		DamageState.DAMAGE2:
			current_state = DamageState.BROKEN
			sprite.visible = false  # Hide the crate sprite
			# Disable collisions immediately to prevent further interactions
			hurtbox.set_deferred("monitoring", false)
			hurtbox.set_deferred("monitorable", false)
			if collision_shape:
				collision_shape.set_deferred("disabled", true)  # Disable the collision shape
			# Play break sound and effects
			AudioUtils.play_with_random_pitch(crate_break_sound, 0.9, 1.1)
			_spawn_broken_pieces()
			# Queue free with a small delay to allow effects to play
			get_tree().create_timer(0.5).timeout.connect(queue_free)

func _instant_break():
	# Instant break for dash attacks
	current_state = DamageState.BROKEN
	sprite.visible = false  # Hide the crate sprite
	# Disable collisions immediately to prevent further interactions
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)  # Disable the collision shape
	
	# Play break sound and effects
	AudioUtils.play_with_random_pitch(crate_break_sound, 0.9, 1.1)
	_spawn_dash_break_pieces()  # Use enhanced break effect for dash
	# Queue free with a small delay to allow effects to play
	get_tree().create_timer(0.5).timeout.connect(queue_free)

func _hit_effect():
	# Play hit sound with random pitch
	AudioUtils.play_with_random_pitch(crate_hit_sound, 0.8, 1.2)
	
	# Camera shake for impact - use simple shake for better performance
	var camera := get_viewport().get_camera_2d()
	if camera:
		CameraUtils.camera_shake_simple(camera, 12.0, 0.3)
	
	# Simple hit shake effect
	var tween = create_tween()
	tween.tween_property(sprite, "position", Vector2(2, 0), 0.05)
	tween.tween_property(sprite, "position", Vector2(-2, 0), 0.05)
	tween.tween_property(sprite, "position", Vector2(1, 0), 0.05)
	tween.tween_property(sprite, "position", Vector2(-1, 0), 0.05)
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.05)
	
	# Spawn a few broken pieces on hit
	_spawn_hit_pieces()

func _spawn_hit_pieces() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)

	# Spawn fewer pieces for hit effect (2-4 pieces)
	var count := RNGUtils.randi_range(2, 4)
	for i in count:
		var piece := _get_pooled_piece()
		piece.texture = CRATE_BROKEN_PIECE_TEXTURE
		piece.rotation = RNGUtils.randf_range(-PI, PI)
		piece.scale = Vector2.ONE * RNGUtils.randf_range(0.5, 1.0)  # Smaller pieces for hit effect
		piece.position = Vector2(RNGUtils.randf_range(-10.0, 10.0), RNGUtils.randf_range(-10.0, 10.0))
		piece.z_index = -1
		burst.add_child(piece)

		var start_pos := piece.position
		var rise := RNGUtils.randf_range(3.0, 8.0)  # Less upward movement for hit pieces
		var drift_x := RNGUtils.randf_range(-30.0, 30.0)  # More horizontal spread
		var up_time := RNGUtils.randf_range(0.08, 0.15)
		var down_time := RNGUtils.randf_range(0.3, 0.6)  # Shorter duration than break effect
		var fall_height := RNGUtils.randf_range(50.0, 100.0)  # Less fall distance

		var t := piece.create_tween()
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.5, -rise), up_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(piece, "position", start_pos + Vector2(drift_x, fall_height), down_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(piece, "rotation", piece.rotation + RNGUtils.randf_range(-3.0, 3.0), up_time + down_time)
		t.parallel().tween_property(piece, "modulate:a", 0.0, down_time * 0.8)  # Faster fade
		t.tween_callback(func(): _return_piece_to_pool(piece))  # Return to pool instead of queue_free
	
	# Clean up the burst node after all animations are done
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)

func _spawn_broken_pieces() -> void:
	# Camera shake for destruction - use simple shake for better performance
	var camera := get_viewport().get_camera_2d()
	if camera:
		CameraUtils.camera_shake_simple(camera, 15.0, 0.5)
	
	var parent := get_parent()
	if parent == null:
		return

	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)

	var count := RNGUtils.randi_range(8, 15)
	for i in count:
		var piece := _get_pooled_piece()
		piece.texture = CRATE_BROKEN_PIECE_TEXTURE
		piece.rotation = RNGUtils.randf_range(-PI, PI)
		piece.scale = Vector2.ONE * RNGUtils.randf_range(0.8, 1.3)
		piece.position = Vector2(RNGUtils.randf_range(-20.0, 20.0), RNGUtils.randf_range(-20.0, 20.0))
		piece.z_index = -1
		burst.add_child(piece)

		var start_pos := piece.position
		var rise := RNGUtils.randf_range(5.0, 12.0)  # Less upward movement for weight
		var drift_x := RNGUtils.randf_range(-10.0, 10.0)  # Less horizontal drift
		var up_time := RNGUtils.randf_range(0.08, 0.15)  # Faster initial burst
		var down_time := RNGUtils.randf_range(0.6, 0.9)  # Longer fall time for weight
		var fall_height := RNGUtils.randf_range(100.0, 180.0)  # Heavier fall

		var t := piece.create_tween()
		# Quick initial burst then heavy fall
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.3, -rise), up_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.6, fall_height), down_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Add rotation for tumbling effect
		t.parallel().tween_property(piece, "rotation", piece.rotation + RNGUtils.randf_range(-2.0, 2.0), up_time + down_time)
		# Slower fade for heavier pieces
		t.parallel().tween_property(piece, "modulate:a", 0.0, maxf(0.3, down_time))
		t.tween_callback(func(): _return_piece_to_pool(piece))  # Return to pool instead of queue_free
	
	# Play break sound when particles start falling
	crate_break_sound.global_position = global_position
	AudioUtils.play_with_random_pitch(crate_break_sound, 0.7, 1.3)

	var total_time := 1.2
	get_tree().create_timer(total_time).timeout.connect(burst.queue_free)

func _spawn_dash_break_pieces() -> void:
	# Enhanced camera shake for dash destruction
	var camera := get_viewport().get_camera_2d()
	if camera:
		CameraUtils.camera_shake_simple(camera, 20.0, 0.6)
	
	var parent := get_parent()
	if parent == null:
		return

	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)

	# Spawn more pieces for dash attack (15-25 pieces instead of 8-15)
	var count := RNGUtils.randi_range(15, 25)
	for i in count:
		var piece := _get_pooled_piece()
		piece.texture = CRATE_BROKEN_PIECE_TEXTURE
		piece.rotation = RNGUtils.randf_range(-PI, PI)
		piece.scale = Vector2.ONE * RNGUtils.randf_range(0.7, 1.4)  # Slightly larger variety
		piece.position = Vector2(RNGUtils.randf_range(-25.0, 25.0), RNGUtils.randf_range(-25.0, 25.0))  # Larger spread
		piece.z_index = -1
		burst.add_child(piece)

		var start_pos := piece.position
		var rise := RNGUtils.randf_range(8.0, 15.0)  # More upward movement for dramatic effect
		var drift_x := RNGUtils.randf_range(-40.0, 40.0)  # Much more horizontal spread
		var up_time := RNGUtils.randf_range(0.06, 0.12)  # Faster initial burst
		var down_time := RNGUtils.randf_range(0.8, 1.2)  # Longer fall time
		var fall_height := RNGUtils.randf_range(120.0, 200.0)  # Higher fall

		var t := piece.create_tween()
		# More dramatic initial burst with explosive force
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.4, -rise), up_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.8, fall_height), down_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# More rotation for tumbling effect
		t.parallel().tween_property(piece, "rotation", piece.rotation + RNGUtils.randf_range(-3.0, 3.0), up_time + down_time)
		# Slower fade for heavier pieces
		t.parallel().tween_property(piece, "modulate:a", 0.0, maxf(0.4, down_time))
		t.tween_callback(func(): _return_piece_to_pool(piece))  # Return to pool instead of queue_free
	
	# Play break sound when particles start falling
	crate_break_sound.global_position = global_position
	AudioUtils.play_with_random_pitch(crate_break_sound, 0.7, 1.3)

	var total_time := 1.5  # Slightly longer for dash effect
	get_tree().create_timer(total_time).timeout.connect(burst.queue_free)
