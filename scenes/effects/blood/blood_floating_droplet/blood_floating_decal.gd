extends "res://scenes/effects/blood/particle.gd"

const BLOOD_SPRITES = [
	"res://sprites/effects/blood/blood1.png",
	"res://sprites/effects/blood/blood2.png"
]

# Configurable properties
@export var float_duration_min: float = 0.3
@export var float_duration_max: float = 0.5
@export var drift_x_min: float = -60.0
@export var drift_x_max: float = 60.0
@export var drift_y_min: float = -35.0
@export var drift_y_max: float = 35.0
@export var particle_lifetime: float = 8.0
@export var fade_alpha: float = 0.6

var float_duration: float = 0.0  # How long to move before sticking
var float_age: float = 0.0
var is_floating: bool = true
var float_drift: Vector2 = Vector2.ZERO
var has_stuck_in_air: bool = false

func _ready() -> void:
	# Override particle properties for floating blood decal
	particle_gravity = 0.0  # No gravity - stays in air
	lifetime = particle_lifetime
	fade_alpha_multiplier = fade_alpha
	
	# Set random floating duration
	float_duration = randf_range(float_duration_min, float_duration_max)
	
	# Set random drift for floating effect
	float_drift = Vector2(randf_range(drift_x_min, drift_x_max), randf_range(drift_y_min, drift_y_max))
	
	
	super._ready()

func _setup_particle_appearance() -> void:
	# Set up floating blood decal appearance using existing sprites
	if sprite:
		# Random blood sprite
		var random_blood = BLOOD_SPRITES[randi() % BLOOD_SPRITES.size()]
		var texture = load(random_blood)
		if texture:
			sprite.texture = texture
			sprite.centered = true
			
			# Random scale and rotation for variety
			var scale_factor = randf_range(0.3, 0.6)  # Increased from 0.15-0.4
			sprite.scale = Vector2(scale_factor, scale_factor)
			sprite.rotation = randf() * PI * 2
			
			# Disable texture filtering for crisp pixels
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _physics_process(delta: float) -> void:
	if has_stuck or has_stuck_in_air:
		return
	
	age += delta
	
	if is_floating:
		float_age += delta
		
		# Apply drift while floating
		global_position += float_drift * delta
		
		# Apply slight upward bias while floating
		velocity.y += -20.0 * delta
		global_position += velocity * delta
		
		# Check if floating duration is over - then stick in air
		if float_age >= float_duration:
			is_floating = false
			has_stuck_in_air = true
			velocity = Vector2.ZERO  # Stop all movement
			float_drift = Vector2.ZERO
	# Should not reach here anymore since decals stick in air
	
	# Fade out over lifetime - very slow fade for stuck decals
	if sprite:
		var alpha = max(0.0, 1.0 - (age / lifetime))
		sprite.modulate.a = alpha * fade_alpha_multiplier
	
	# Remove if lifetime exceeded
	if age >= lifetime:
		queue_free()

func _should_collide_with(body: Node) -> bool:
	# Floating blood decals only collide if they haven't stuck in air yet
	if has_stuck_in_air:
		return false
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground") or body.is_in_group("colliders") or body.is_in_group("enemies") or body.is_in_group("player")

func _on_collision(body: Node) -> void:
	# Floating decals don't create additional decals on collision
	# They just stick to whatever they hit
	if not has_stuck_in_air:
		is_floating = false
		has_stuck_in_air = true
		velocity = Vector2.ZERO
		float_drift = Vector2.ZERO
