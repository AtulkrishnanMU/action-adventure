extends BaseEnemy

func _ready() -> void:
	max_hp = 20  # Set max HP to 20 for small enemy
	super._ready()  # Call parent's _ready()
	# Set specific values for small enemy
	min_move_speed = 220.0  # Set speed range for small enemy
	max_move_speed = 280.0
	detection_range = 300.0  # Increased from 250.0
	attack_range = 80.0  # Increased from 60.0
	attack_cooldown = 0.8  # Reduced from 1.5 for more frequent attacks
