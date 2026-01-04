extends Node2D

const BLOOD_DROPLET_SCENE := preload("res://scenes/effects/blood/blood_droplet/blood_droplet.tscn")
const BLOOD_FLOATING_DECAL_SCENE := preload("res://scenes/effects/blood/blood_floating_droplet/blood_floating_decal.tscn")
const AudioUtils = preload("res://scripts/utils/audio_utils.gd")
const DROPLET_COUNT := 35
const FLOATING_DECAL_COUNT := 15  # Increased count since we're removing droplets
const DEAD_ENEMY_DROPLET_COUNT := 20  # Reduced blood for dead enemies
const DEAD_ENEMY_FLOATING_DECAL_COUNT := 10  # Increased for dead enemies
const DASH_DROPLET_COUNT := 60  # Increased blood for dash attacks
const DASH_FLOATING_DECAL_COUNT := 25  # Increased decals for dash attacks

# Blood droplet pooling system
static var droplet_pool: Array[Node] = []
static var max_droplet_pool_size: int = 100
static var droplet_pool_parent: Node2D

# Blood splash management
static var active_splashes: Array[Node] = []
static var max_concurrent_splashes: int = 5

# Configurable speed values
@export var droplet_min_speed: float = 600.0
@export var droplet_max_speed: float = 900.0
@export var dead_enemy_droplet_min_speed: float = 750.0
@export var dead_enemy_droplet_max_speed: float = 1050.0
@export var floating_decal_min_speed: float = 300.0
@export var floating_decal_max_speed: float = 450.0
@export var dead_enemy_floating_decal_min_speed: float = 400.0
@export var dead_enemy_floating_decal_max_speed: float = 600.0

var direction: Vector2 = Vector2.RIGHT  # Default direction, can be set from outside
var is_dead_enemy: bool = false  # Flag to reduce blood amount
var is_dash_attack: bool = false  # Flag to increase blood amount for dash attacks

@onready var audio_player = $BloodSplash

func _ready() -> void:
	# Initialize droplet pool if not already done
	_setup_droplet_pool.call_deferred()  # Defer to avoid physics flush error
	
	# Manage concurrent splashes to prevent performance issues
	_manage_concurrent_splashes()
	
	# Add this splash to tracking
	active_splashes.append(self)
	
	# Play blood splash sound with random pitch
	if audio_player:
		AudioUtils.play_with_random_pitch(audio_player, 0.8, 1.2)
	
	call_deferred("_spawn_blood_droplets")  # Also defer spawning

# Manage concurrent splash limit
static func _manage_concurrent_splashes() -> void:
	# Remove any finished splashes from tracking
	active_splashes = active_splashes.filter(func(splash): return is_instance_valid(splash))
	
	# If too many active splashes, remove the oldest ones
	while active_splashes.size() >= max_concurrent_splashes:
		var oldest_splash = active_splashes[0]
		if is_instance_valid(oldest_splash):
			oldest_splash.queue_free()
		active_splashes.erase(oldest_splash)

# Static pool management functions
static func _setup_droplet_pool() -> void:
	if droplet_pool.size() > 0:
		return  # Pool already initialized
	
	# Pre-allocate all droplets at once
	if not droplet_pool_parent:
		droplet_pool_parent = Node2D.new()
		droplet_pool_parent.name = "BloodDropletPool"
		# Add to scene tree safely
		if Engine.get_main_loop() and Engine.get_main_loop().current_scene:
			Engine.get_main_loop().current_scene.add_child(droplet_pool_parent)
			droplet_pool_parent.visible = false
	
	# Pre-allocate all droplets with deferred call to avoid physics errors
	for i in range(max_droplet_pool_size):
		var droplet = BLOOD_DROPLET_SCENE.instantiate()
		# Don't add to parent immediately to avoid physics conflicts
		droplet_pool.append(droplet)
	
	# Add all droplets to parent in a deferred call
	_add_droplets_to_pool_parent.call_deferred()

static func _add_droplets_to_pool_parent() -> void:
	"""Helper function to add droplets to pool parent after physics flush"""
	if not droplet_pool_parent:
		return
	
	# Filter out any invalid droplets before processing
	var valid_droplets: Array[Node] = []
	for droplet in droplet_pool:
		if droplet and is_instance_valid(droplet):
			valid_droplets.append(droplet)
	
	# Update the pool with only valid droplets
	droplet_pool = valid_droplets
	
	# Add valid droplets to parent
	for droplet in droplet_pool:
		if droplet and is_instance_valid(droplet) and not droplet.get_parent():
			droplet_pool_parent.add_child(droplet)
			droplet.visible = false

static func _get_pooled_droplet() -> Node:
	_setup_droplet_pool()  # Ensure pool exists
	
	# Filter out invalid droplets and get a valid one
	while droplet_pool.size() > 0:
		var droplet = droplet_pool.pop_back()
		if droplet and is_instance_valid(droplet):
			# Remove from pool parent before returning
			if droplet.get_parent():
				droplet.get_parent().remove_child(droplet)
			droplet.visible = true
			return droplet
		# If droplet is invalid, continue loop to find next one
	
	# Pool exhausted or all invalid, create new droplet (fallback)
	return BLOOD_DROPLET_SCENE.instantiate()

static func _return_droplet_to_pool(droplet: Node) -> void:
	# Simple return to pool
	if droplet and is_instance_valid(droplet) and droplet_pool.size() < max_droplet_pool_size:
		droplet.visible = false
		droplet_pool.append(droplet)

func set_direction(dir: Vector2) -> void:
	direction = dir.normalized()

func set_dead_enemy(dead: bool) -> void:
	is_dead_enemy = dead

func set_dash_attack(dash: bool) -> void:
	is_dash_attack = dash

func _spawn_blood_droplets() -> void:
	var droplet_count = DEAD_ENEMY_DROPLET_COUNT if is_dead_enemy else DROPLET_COUNT
	var floating_decal_count = DEAD_ENEMY_FLOATING_DECAL_COUNT if is_dead_enemy else FLOATING_DECAL_COUNT
	
	# Override with dash attack amounts if this is a dash attack
	if is_dash_attack:
		droplet_count = DASH_DROPLET_COUNT
		floating_decal_count = DASH_FLOATING_DECAL_COUNT
	
	# Spawn regular falling droplets (using object pooling)
	for i in range(droplet_count):
		var droplet = _get_pooled_droplet()
		if droplet:
			add_child(droplet)
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/3, PI/3)  # Spread in front arc
			var angle = direction.angle() + angle_offset
			# Use configurable speed values
			var speed = randf_range(dead_enemy_droplet_min_speed, dead_enemy_droplet_max_speed) if is_dead_enemy else randf_range(droplet_min_speed, droplet_max_speed)
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			droplet.position = Vector2(randf_range(-8, 8), randf_range(-8, 8))
			if droplet.has_method("set_velocity"):
				droplet.set_velocity(velocity_dir * speed)
			elif "velocity" in droplet:
				droplet.velocity = velocity_dir * speed
			if droplet.has_method("set_lifetime"):
				droplet.set_lifetime(randf_range(1.5, 2.5))
			elif "lifetime" in droplet:
				droplet.lifetime = randf_range(1.5, 2.5)
			
			# Connect to particle cleanup for pooling
			if droplet.has_signal("particle_finished"):
				droplet.particle_finished.connect(_on_droplet_finished)
			elif droplet.has_signal("tree_exiting"):
				droplet.tree_exiting.connect(_on_droplet_finished)
	
	# Spawn floating blood decals (make them independent to persist)
	for i in range(floating_decal_count):
		var floating_decal = BLOOD_FLOATING_DECAL_SCENE.instantiate()
		if floating_decal:
			# Add floating decals to the scene root instead of splash node
			# This makes them persist even after splash is destroyed
			var scene_tree = Engine.get_main_loop() as SceneTree
			if scene_tree and scene_tree.current_scene:
				scene_tree.current_scene.add_child(floating_decal)
			
			# Random initial velocity and position based on direction
			var angle_offset = randf_range(-PI/4, PI/4)  # Spread for decals
			
			# Calculate base angle from direction
			var base_angle = direction.angle()
			
			# Apply upward bias relative to direction
			var angle = base_angle + angle_offset
			if direction.x > 0:  # Shooting right
				angle -= PI/4  # Bias upward
			else:  # Shooting left
				angle += PI/4  # Bias upward (relative to left direction)
			
			# Use configurable speed values
			var speed = randf_range(dead_enemy_floating_decal_min_speed, dead_enemy_floating_decal_max_speed) if is_dead_enemy else randf_range(floating_decal_min_speed, floating_decal_max_speed)
			var velocity_dir = Vector2.RIGHT.rotated(angle)
			
			floating_decal.global_position = global_position + Vector2(randf_range(-6, 6), randf_range(-6, -2))  # Start position
			floating_decal.velocity = velocity_dir * speed

# Callback for when droplets finish their lifecycle
func _on_droplet_finished(droplet: Node) -> void:
	# Return droplet to pool instead of destroying it
	_return_droplet_to_pool(droplet)

# Clean up function for when blood splash is removed
func _exit_tree() -> void:
	# Remove from active splashes tracking
	active_splashes.erase(self)
	
	# Clean up any remaining droplets that might still be children
	for child in get_children():
		if not child:
			continue
		
		# Check if child is a blood droplet using multiple methods
		var is_droplet = false
		
		# Method 1: Check group membership
		if child.is_in_group("blood_droplet"):
			is_droplet = true
		
		# Method 2: Check script path safely
		elif child.get_script() and child.get_script().get_path().ends_with("blood_droplet.gd"):
			is_droplet = true
		
		# Method 3: Check class name if available
		elif child.get_script() and child.get_script().get_global_name() == "BloodDroplet":
			is_droplet = true
		
		if is_droplet:
			_return_droplet_to_pool(child)
