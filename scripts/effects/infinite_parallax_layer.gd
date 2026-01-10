extends ParallaxLayer

class_name InfiniteParallaxLayer

@export var texture_width: float = 550.0

var sprites: Array[Sprite2D] = []
var initial_positions: Array[float] = []

func _ready():
	_setup_infinite_sprites()

func _setup_infinite_sprites():
	# Get the original sprite
	var original_sprite = $Sprite2D
	if not original_sprite:
		push_error("No Sprite2D found as child of InfiniteParallaxLayer")
		return
	
	# Store original sprite position and create additional sprites
	initial_positions.append(original_sprite.position.x)
	sprites.append(original_sprite)
	
	# Create enough sprites to cover screen + buffer
	var screen_width = get_viewport().get_visible_rect().size.x
	var needed_sprites = ceil(screen_width / texture_width) + 3
	
	for i in range(1, needed_sprites):
		var new_sprite = original_sprite.duplicate()
		add_child(new_sprite)
		sprites.append(new_sprite)
		var new_pos = original_sprite.position.x + (texture_width * i)
		new_sprite.position = Vector2(new_pos, 0)
		initial_positions.append(new_pos)

func _process(_delta):
	_update_sprite_positions()

func _update_sprite_positions():
	# Get the current layer offset to determine where we are in the cycle
	var layer_offset = self.get_global_transform().origin.x
	
	# Calculate how many texture widths we've moved
	var movement_cycles = floor(layer_offset / texture_width)
	
	# Update each sprite position based on movement
	for i in range(sprites.size()):
		var sprite = sprites[i]
		var base_pos = initial_positions[i]
		
		# Calculate new position based on movement cycles
		var new_x = base_pos - (movement_cycles * texture_width)
		
		# If we've moved too far left, wrap around to the right
		if new_x < -texture_width * 2:
			new_x += texture_width * sprites.size()
		# If we've moved too far right, wrap around to the left  
		elif new_x > texture_width * 2:
			new_x -= texture_width * sprites.size()
			
		sprite.position.x = new_x
