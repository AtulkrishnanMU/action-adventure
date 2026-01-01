extends Node2D

@onready var grass_blade1 = $GrassBlade1
@onready var grass_blade2 = $GrassBlade2
@onready var area_2d = $Area2D

const CUT_GRASS_BLADE_TEXTURE: Texture2D = preload("res://sprites/objects/grass_blade_cut.png")

var time = 0.0
var blade1_angle = 0.0
var blade2_angle = 0.0

# Animation parameters
var max_rotation = 8.0  # Maximum rotation in degrees
var blade1_speed = 2.5   # Speed for blade 1
var blade2_speed = 3.0   # Speed for blade 2 (slightly different for offset)
var blade1_phase = 0.0    # Phase offset for blade 1
var blade2_phase = 1.5    # Phase offset for blade 2 (creates timing difference)

# Collision reaction parameters
var collision_rotation = 30.0  # Rotation amount when hit
var recovery_speed = 2.0      # Speed to return to normal
var is_hit = false
var hit_time = 0.0
var blade1_hit_angle = 0.0
var blade2_hit_angle = 0.0

func _ready():
	# Randomize starting positions for each blade
	blade1_phase = randf() * TAU  # Random phase between 0 and 2π
	blade2_phase = randf() * TAU  # Random phase between 0 and 2π

func _process(delta):
	time += delta
	
	if is_hit:
		# Handle collision recovery
		hit_time += delta
		var recovery_progress = min(hit_time * recovery_speed, 1.0)
		
		# Ease out back to normal animation
		var ease_factor = 1.0 - recovery_progress
		
		# Calculate target normal angles
		var target1 = sin(time * blade1_speed + blade1_phase) * max_rotation
		var target2 = sin(time * blade2_speed + blade2_phase) * max_rotation
		
		# Blend from hit angle back to normal
		blade1_angle = blade1_hit_angle * ease_factor + target1 * (1.0 - ease_factor)
		blade2_angle = blade2_hit_angle * ease_factor + target2 * (1.0 - ease_factor)
		
		# Check if recovery is complete
		if recovery_progress >= 1.0:
			is_hit = false
			hit_time = 0.0
	else:
		# Normal animation
		blade1_angle = sin(time * blade1_speed + blade1_phase) * max_rotation
		blade2_angle = sin(time * blade2_speed + blade2_phase) * max_rotation
	
	# Apply rotations
	grass_blade1.rotation_degrees = blade1_angle
	grass_blade2.rotation_degrees = blade2_angle

func _on_area_entered(area):
	# Any area entering will make the grass react
	# Get entering object position relative to grass
	var object_pos = area.global_position
	var grass_pos = global_position
	var direction = (object_pos - grass_pos).normalized()
	
	# Calculate rotation away from object (negative to rotate away)
	var away_angle_x = -direction.x * collision_rotation
	var away_angle_y = -direction.y * collision_rotation * 0.5  # Less vertical impact
	
	# Set hit angles based on object position
	blade1_hit_angle = away_angle_x + away_angle_y
	blade2_hit_angle = away_angle_x + away_angle_y
	
	is_hit = true
	hit_time = 0.0

func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_hitbox"):
		_spawn_cut_grass_blades()
		queue_free()

func _spawn_cut_grass_blades() -> void:
	var parent := get_parent()
	if parent == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var burst := Node2D.new()
	burst.global_position = global_position
	parent.add_child(burst)

	var count := rng.randi_range(5, 11)
	for i in count:
		var blade := Sprite2D.new()
		blade.texture = CUT_GRASS_BLADE_TEXTURE
		blade.rotation = rng.randf_range(-0.7, 0.7)
		blade.scale = Vector2.ONE * rng.randf_range(0.8, 1.15)
		blade.position = Vector2(rng.randf_range(-12.0, 12.0), rng.randf_range(-8.0, 8.0))
		blade.z_index = -1
		burst.add_child(blade)

		var start_pos := blade.position
		var rise := rng.randf_range(8.0, 16.0)  # Reduced upward movement
		var drift_x := rng.randf_range(-15.0, 15.0)  # Reduced horizontal drift
		var up_time := rng.randf_range(0.1, 0.2)  # Faster upward movement
		var down_time := rng.randf_range(0.4, 0.7)  # Longer fall time
		var fall_height := rng.randf_range(60.0, 120.0)  # Increased fall distance

		var t := blade.create_tween()
		t.tween_property(blade, "position", start_pos + Vector2(drift_x * 0.5, -rise), up_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(blade, "position", start_pos + Vector2(drift_x * 0.8, fall_height), down_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(blade, "rotation", blade.rotation + rng.randf_range(-4.0, 4.0), up_time + down_time)
		t.parallel().tween_property(blade, "modulate:a", 0.0, maxf(0.15, down_time - 0.1))
		t.tween_callback(blade.queue_free)

	var total_time := 0.8
	get_tree().create_timer(total_time).timeout.connect(burst.queue_free)
