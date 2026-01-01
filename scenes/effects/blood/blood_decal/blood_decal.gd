extends Node2D

const BLOOD_SPRITES = [
	"res://sprites/effects/blood/blood1.png",
	"res://sprites/effects/blood/blood2.png"
]

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	# Set blood decal appearance using existing sprites
	if sprite:
		# Random blood sprite
		var random_blood = BLOOD_SPRITES[randi() % BLOOD_SPRITES.size()]
		var texture = load(random_blood)
		if texture:
			sprite.texture = texture
			sprite.centered = true
			
			# Random scale and rotation for variety
			var scale_factor = randf_range(0.4, 1.0)  # Increased from 0.2-0.6
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.rotation = randf() * PI
			
			# Disable texture filtering for crisp pixels
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
