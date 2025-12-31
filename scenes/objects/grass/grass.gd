extends Node2D

@onready var grass_blade1 = $GrassBlade1
@onready var grass_blade2 = $GrassBlade2
@onready var area_2d = $Area2D

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
	# Check if the entering area is the player's area
	if area.name == "PlayerArea":
		# Get player position relative to grass
		var player_pos = area.global_position
		var grass_pos = global_position
		var direction = (player_pos - grass_pos).normalized()
		
		# Calculate rotation away from player (negative to rotate away)
		var away_angle_x = -direction.x * collision_rotation
		var away_angle_y = -direction.y * collision_rotation * 0.5  # Less vertical impact
		
		# Set hit angles based on player position
		blade1_hit_angle = away_angle_x + away_angle_y
		blade2_hit_angle = away_angle_x + away_angle_y
		
		is_hit = true
		hit_time = 0.0
