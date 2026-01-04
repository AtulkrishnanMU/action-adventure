class_name BaseLevel
extends Node2D

# UI scene that will be automatically added to all levels
const UI_SCENE_PATH = "res://scenes/ui/ui.tscn"
const LEVEL_START_SOUND_PATH = "res://sounds/level-start.mp3"

# Reference to the UI instance
var ui_instance: Node = null

# Level configuration
@export var level_name: String = ""
@export var player_spawn_position: Vector2 = Vector2.ZERO

# Virtual methods that child levels can override
func _ready() -> void:
	# Play level start sound
	_play_level_start_sound()
	
	# Automatically add UI to the level
	_add_ui_to_level()
	
	# Add dust particles effect
	_add_dust_particles()
	
	# Call level-specific initialization
	_initialize_level()
	
	# Connect to camera movement to keep particles visible
	_connect_camera_tracking()

func _initialize_level() -> void:
	# Override in child classes for level-specific initialization
	pass

func _add_ui_to_level() -> void:
	# Load and add UI scene if it exists
	if ResourceLoader.exists(UI_SCENE_PATH):
		var ui_scene = load(UI_SCENE_PATH)
		if ui_scene:
			ui_instance = ui_scene.instantiate()
			add_child(ui_instance)
			# Move UI to the top of the scene tree for proper rendering order
			move_child(ui_instance, get_child_count() - 1)
			print("UI automatically added to level: ", level_name)
		else:
			push_error("Failed to load UI scene from: ", UI_SCENE_PATH)
	else:
		push_warning("UI scene not found at: ", UI_SCENE_PATH)

func _add_dust_particles() -> void:
	# Set visibility rect to cover the entire viewport
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Create 3 layers of dust particles with different opacity
	var opacity_levels = [0.4, 0.25, 0.15]
	var z_indices = [-50, -75, -100]  # Different background layers
	
	for i in range(3):
		# Create GPUParticles2D for dust effect
		var dust_particles = GPUParticles2D.new()
		add_child(dust_particles)
		
		# Configure particle system
		dust_particles.name = "DustParticles_" + str(i)
		dust_particles.position = Vector2.ZERO  # Center of the level
		dust_particles.emitting = true
		dust_particles.amount = 30
		dust_particles.lifetime = 8.0
		dust_particles.visibility_rect = Rect2(-viewport_size / 2, viewport_size)
		dust_particles.z_index = z_indices[i]  # Different background layers
		
		# Configure particle process material
		var process_material = ParticleProcessMaterial.new()
		process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_material.emission_box_extents = Vector3(viewport_size.x, viewport_size.y, 100)
		process_material.direction = Vector3(0, -1, 0)
		process_material.spread = 30.0
		process_material.initial_velocity_min = 10.0
		process_material.initial_velocity_max = 30.0
		process_material.angular_velocity_min = -45.0
		process_material.angular_velocity_max = 45.0
		process_material.gravity = Vector3.ZERO
		process_material.scale_min = 0.4
		process_material.scale_max = 0.8
		process_material.color = Color.WHITE
		process_material.color.a = opacity_levels[i]  # Set opacity for this layer
		
		# Set up texture for particles (use particle sprite)
		var dust_texture_path = "res://sprites/effects/particle.png"
		if ResourceLoader.exists(dust_texture_path):
			var dust_texture = load(dust_texture_path)
			dust_particles.texture = dust_texture
		
		dust_particles.process_material = process_material
	
	print("3 layers of dust particles automatically added to level: ", level_name)

func _connect_camera_tracking() -> void:
	# Find the camera in the scene tree
	var camera = get_viewport().get_camera_2d()
	if camera:
		# Set up continuous camera tracking
		set_process(true)
		# Initial positioning
		_update_particles_position(camera.global_position)
	else:
		# Try to find camera after a short delay (in case it's not ready yet)
		call_deferred("_deferred_camera_connect")

func _deferred_camera_connect() -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		set_process(true)
		_update_particles_position(camera.global_position)

func _process(_delta: float) -> void:
	var camera = get_viewport().get_camera_2d()
	if camera:
		_update_particles_position(camera.global_position)

func _update_particles_position(camera_position: Vector2) -> void:
	# Update all 3 dust particle layers
	for i in range(3):
		var dust_particles = get_node_or_null("DustParticles_" + str(i))
		if dust_particles:
			dust_particles.global_position = camera_position

# Helper methods for level management
func _play_level_start_sound() -> void:
	if FileAccess.file_exists(LEVEL_START_SOUND_PATH):
		var audio_stream = load(LEVEL_START_SOUND_PATH)
		if audio_stream:
			var audio_player = AudioStreamPlayer.new()
			audio_player.stream = audio_stream
			add_child(audio_player)
			audio_player.play()
			# Queue free the player when done to clean up
			await audio_player.finished
			audio_player.queue_free()

func get_ui() -> Node:
	return ui_instance

func set_player_spawn_position(position: Vector2) -> void:
	player_spawn_position = position

# Level completion/transition methods
func complete_level() -> void:
	# Override in child classes for level completion logic
	print("Level completed: ", level_name)

func restart_level() -> void:
	# Reload the current scene
	get_tree().reload_current_scene()

# Cleanup
func _exit_tree() -> void:
	# Clean up UI instance if it exists
	if ui_instance and is_instance_valid(ui_instance):
		ui_instance.queue_free()
