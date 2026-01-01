extends Node2D

const CameraUtils = preload("res://scripts/utils/camera_utils.gd")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")

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

var current_state = DamageState.INTACT
var hits_taken = 0

func _ready():
	# Set initial texture
	sprite.texture = CRATE_TEXTURE

func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_hitbox"):
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

func _hit_effect():
	# Play hit sound with random pitch
	AudioUtils.play_with_random_pitch(crate_hit_sound, 0.8, 1.2)
	
	# Camera shake for impact
	var camera := get_viewport().get_camera_2d()
	if camera:
		CameraUtils.camera_shake(camera, 12.0, 0.3)
	
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

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)

	# Spawn fewer pieces for hit effect (2-4 pieces)
	var count := rng.randi_range(2, 4)
	for i in count:
		var piece := Sprite2D.new()
		piece.texture = CRATE_BROKEN_PIECE_TEXTURE
		piece.rotation = rng.randf_range(-PI, PI)
		piece.scale = Vector2.ONE * rng.randf_range(0.5, 1.0)  # Smaller pieces for hit effect
		piece.position = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		piece.z_index = -1
		burst.add_child(piece)

		var start_pos := piece.position
		var rise := rng.randf_range(3.0, 8.0)  # Less upward movement for hit pieces
		var drift_x := rng.randf_range(-30.0, 30.0)  # More horizontal spread
		var up_time := rng.randf_range(0.08, 0.15)
		var down_time := rng.randf_range(0.3, 0.6)  # Shorter duration than break effect
		var fall_height := rng.randf_range(50.0, 100.0)  # Less fall distance

		var t := piece.create_tween()
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.5, -rise), up_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(piece, "position", start_pos + Vector2(drift_x, fall_height), down_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(piece, "rotation", piece.rotation + rng.randf_range(-3.0, 3.0), up_time + down_time)
		t.parallel().tween_property(piece, "modulate:a", 0.0, down_time * 0.8)  # Faster fade
		t.tween_callback(piece.queue_free)
	
	# Clean up the burst node after all animations are done
	get_tree().create_timer(1.0).timeout.connect(burst.queue_free)

func _spawn_broken_pieces() -> void:
	# Camera shake for destruction
	var camera := get_viewport().get_camera_2d()
	if camera:
		CameraUtils.camera_shake(camera, 15.0, 0.5)
	
	var parent := get_parent()
	if parent == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)

	var count := rng.randi_range(8, 15)
	for i in count:
		var piece := Sprite2D.new()
		piece.texture = CRATE_BROKEN_PIECE_TEXTURE
		piece.rotation = rng.randf_range(-PI, PI)
		piece.scale = Vector2.ONE * rng.randf_range(0.8, 1.3)
		piece.position = Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-20.0, 20.0))
		piece.z_index = -1
		burst.add_child(piece)

		var start_pos := piece.position
		var rise := rng.randf_range(5.0, 12.0)  # Less upward movement for weight
		var drift_x := rng.randf_range(-10.0, 10.0)  # Less horizontal drift
		var up_time := rng.randf_range(0.08, 0.15)  # Faster initial burst
		var down_time := rng.randf_range(0.6, 0.9)  # Longer fall time for weight
		var fall_height := rng.randf_range(100.0, 180.0)  # Heavier fall

		var t := piece.create_tween()
		# Quick initial burst then heavy fall
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.3, -rise), up_time).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		t.tween_property(piece, "position", start_pos + Vector2(drift_x * 0.6, fall_height), down_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Add rotation for tumbling effect
		t.parallel().tween_property(piece, "rotation", piece.rotation + rng.randf_range(-2.0, 2.0), up_time + down_time)
		# Slower fade for heavier pieces
		t.parallel().tween_property(piece, "modulate:a", 0.0, maxf(0.3, down_time))
		t.tween_callback(piece.queue_free)
	
	# Play break sound when particles start falling
	crate_break_sound.global_position = global_position
	AudioUtils.play_with_random_pitch(crate_break_sound, 0.7, 1.3)

	var total_time := 1.2
	get_tree().create_timer(total_time).timeout.connect(burst.queue_free)
