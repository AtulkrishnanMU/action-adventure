extends "res://scenes/effects/blood/particle.gd"

signal particle_finished(particle)

const BLOOD_DECAL_SCENE := preload("res://scenes/effects/blood/blood_decal/blood_decal.tscn")
const BLOOD_SPRITES = [
	"res://sprites/effects/blood/blood1.png",
	"res://sprites/effects/blood/blood2.png"
]

# Configurable properties
@export var particle_gravity_override: float = 1200.0  # Increased from 800.0
@export var particle_lifetime: float = 2.0
@export var fade_alpha: float = 0.8

# Pooling support
var is_pooled: bool = false

func _ready() -> void:
	# Override particle properties for blood
	particle_gravity = particle_gravity_override
	lifetime = particle_lifetime
	fade_alpha_multiplier = fade_alpha
	
	# Add to blood_droplet group for identification
	add_to_group("blood_droplet")
	
	super._ready()

func _physics_process(delta: float) -> void:
	if has_stuck:
		return
	
	age += delta
	
	# Apply gravity
	velocity.y += particle_gravity * delta
	
	# Move and check collision
	global_position += velocity * delta
	
	# Fade out over lifetime
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * fade_alpha_multiplier
	
	# Remove if lifetime exceeded - emit signal instead of queue_free
	if age >= lifetime:
		_emit_finished_and_cleanup()

func _emit_finished_and_cleanup() -> void:
	particle_finished.emit(self)
	if not is_pooled:
		queue_free()

# Pooling support methods
func reset_particle() -> void:
	# Reset particle properties for reuse
	age = 0.0
	has_stuck = false
	velocity = Vector2.ZERO
	visible = true
	if sprite:
		sprite.modulate.a = 1.0
	# Reset collision
	if collision_shape:
		collision_shape.disabled = false

func set_velocity(new_velocity: Vector2) -> void:
	velocity = new_velocity

func set_lifetime(new_lifetime: float) -> void:
	lifetime = new_lifetime

func _setup_particle_appearance() -> void:
	# Set up blood droplet appearance using existing sprites
	if sprite:
		# Random blood sprite
		var random_blood = BLOOD_SPRITES[randi() % BLOOD_SPRITES.size()]
		var texture = load(random_blood)
		if texture:
			sprite.texture = texture
			sprite.centered = true
			
			# Random scale and rotation for variety
			var scale_factor = randf_range(0.2, 0.5)  # Increased from 0.1-0.3
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.rotation = randf() * PI * 2
			
			# Disable texture filtering for crisp pixels
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _should_collide_with(body: Node) -> bool:
	# Blood collides with more surfaces including characters
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("colliders") or body.is_in_group("enemies") or body.is_in_group("player")

func _on_collision(body: Node) -> void:
	# Create blood decal on collision
	_create_blood_decal()
	
	# Start disappearance timer after hitting floor
	if body is TileMap or body.is_in_group("ground") or body.is_in_group("colliders"):
		# Set a short timer to disappear after 0.5 seconds
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(_emit_finished_and_cleanup)
	else:
		# For other collisions, emit finished immediately
		_emit_finished_and_cleanup()

func _create_blood_decal() -> void:
	var decal = BLOOD_DECAL_SCENE.instantiate()
	if decal:
		# Add decal to the scene tree
		var scene = get_tree().current_scene
		scene.add_child(decal)
		
		decal.global_position = global_position
		
		# Random rotation and scale for variety
		decal.rotation = randf() * PI
		var scale_factor = randf_range(0.4, 1.0)  # Increased from 0.2-0.6
		decal.scale = Vector2(scale_factor, scale_factor)
