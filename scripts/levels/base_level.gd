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
	
	# Call level-specific initialization
	_initialize_level()

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
