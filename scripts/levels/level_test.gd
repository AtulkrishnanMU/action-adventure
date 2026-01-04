extends BaseLevel

# Level-specific configuration for LevelTest
func _initialize_level() -> void:
	# Set level name
	level_name = "Level Test"
	
	# Configure player spawn position (based on current player position in scene)
	player_spawn_position = Vector2(438, 292)
	
	# Any level-specific initialization
	_setup_level_test_features()

func _setup_level_test_features() -> void:
	# Level test specific setup
	print("Initializing Level Test with ", get_child_count(), " children")
	
	# You can add level-specific logic here
	# For example: spawning enemies, setting up triggers, etc.
	
	# Find and configure any level-specific objects
	_configure_level_objects()

func _configure_level_objects() -> void:
	# Configure any level-specific objects
	# This is where you can set up level-specific behavior
	
	# Example: Find all enemies and set them up
	var enemies = find_children("*", "CharacterBody2D", true, false)
	for enemy in enemies:
		if enemy.name.to_lower().contains("enemy"):
			# Any enemy-specific setup for this level
			pass

# Override level completion if needed
func complete_level() -> void:
	print("Level Test completed!")
	# Add level-specific completion logic
	# For example: show completion screen, unlock next level, etc.
	super.complete_level()

# You can add level-specific methods here
func spawn_additional_enemy(position: Vector2) -> void:
	# Example method to spawn enemies dynamically
	var enemy_scene = load("res://scenes/characters/small_enemy/small_enemy.tscn")
	if enemy_scene:
		var enemy = enemy_scene.instantiate()
		enemy.position = position
		add_child(enemy)
