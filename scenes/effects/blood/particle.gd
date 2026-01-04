class_name Particle
extends Area2D

# Shared particle properties - can be overridden by child classes
var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 2.0
var age: float = 0.0
var has_stuck: bool = false
var particle_gravity: float = 500.0
var fade_alpha_multiplier: float = 0.8

# Batch processing support
static var active_particles: Array[Particle] = []
static var batch_processor: Node2D
static var is_batch_processing_enabled: bool = true
static var max_batch_size: int = 100  # Maximum particles before forcing batch processing
static var performance_stats: Dictionary = {"particles_processed": 0, "batches_processed": 0}

@onready var sprite: Sprite2D = $Sprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set up particle appearance - to be overridden by child classes
	_setup_particle_appearance()
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Register for batch processing if enabled
	if is_batch_processing_enabled:
		# Force batch processing if too many particles
		if active_particles.size() >= max_batch_size:
			_setup_batch_processor()
			active_particles.append(self)
			set_physics_process(false)
		else:
			# Allow individual processing for small numbers
			set_physics_process(true)
	else:
		# Enable individual physics processing if batch processing is disabled
		set_physics_process(true)

# Batch processing system
static func _setup_batch_processor() -> void:
	if not batch_processor:
		var batch_script = load("res://scripts/utils/particle_batch_processor.gd")
		batch_processor = batch_script.new()
		batch_processor.name = "ParticleBatchProcessor"
		# Add to scene tree safely
		if Engine.get_main_loop() and Engine.get_main_loop().current_scene:
			Engine.get_main_loop().current_scene.add_child(batch_processor)

# Batch processing method - called by batch processor
static func _batch_process_particles(delta: float) -> void:
	if not is_batch_processing_enabled:
		return
	
	# Periodically clean up invalid particles (every 10 frames)
	if performance_stats["batches_processed"] % 10 == 0:
		_cleanup_invalid_particles()
	
	# Track performance
	performance_stats["batches_processed"] += 1
	var particles_this_batch = active_particles.size()
	performance_stats["particles_processed"] += particles_this_batch
	
	# Process all active particles in one go
	var particles_to_remove: Array[Particle] = []
	
	for i in range(active_particles.size() - 1, -1, -1):  # Iterate backwards for safe removal
		var particle = active_particles[i]
		
		# Skip invalid particles
		if not particle or not is_instance_valid(particle):
			particles_to_remove.append(particle)
			continue
		
		# Process individual particle
		particle._process_particle_physics(delta)
		
		# Check if particle should be removed
		if particle.age >= particle.lifetime:
			particles_to_remove.append(particle)
			particle._handle_particle_removal()
	
	# Remove dead particles
	for particle in particles_to_remove:
		active_particles.erase(particle)
	
	# Auto-disable batch processing if particle count is low
	if active_particles.size() < max_batch_size * 0.5 and batch_processor:
		# Switch remaining particles back to individual processing
		for particle in active_particles:
			if is_instance_valid(particle):
				particle.set_physics_process(true)
		batch_processor.queue_free()
		batch_processor = null

# Cleanup function to remove invalid particles
static func _cleanup_invalid_particles() -> void:
	var valid_particles: Array[Particle] = []
	for particle in active_particles:
		if particle and is_instance_valid(particle):
			valid_particles.append(particle)
	active_particles = valid_particles

# Individual particle processing method
func _process_particle_physics(delta: float) -> void:
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

# Handle particle removal
func _handle_particle_removal() -> void:
	# Use get() method to safely check for pooling support
	var pooled_status = self.get("is_pooled")
	if pooled_status != null and pooled_status:
		# For pooled particles, check for signal and emit if available
		if self.has_signal("particle_finished"):
			self.emit_signal("particle_finished", self)
		else:
			# Fallback for pooled particles without signal
			queue_free()
	else:
		# For non-pooled particles, queue for removal
		queue_free()

func _physics_process(delta: float) -> void:
	# Only process if batch processing is disabled (fallback)
	if not is_batch_processing_enabled:
		_process_particle_physics(delta)
		if age >= lifetime:
			_handle_particle_removal()

func _on_body_entered(body: Node) -> void:
	if has_stuck:
		return
	
	# Check if hit a solid surface - can be overridden by child classes
	if _should_collide_with(body):
		_on_collision(body)
		has_stuck = true
		# Handle removal through batch system or direct removal
		if is_batch_processing_enabled:
			# Remove from active particles list
			Particle.active_particles.erase(self)
			_handle_particle_removal()
		else:
			# Direct removal for individual processing
			_handle_particle_removal()

func _on_area_entered(area: Area2D) -> void:
	if has_stuck:
		return
	# Handle area collisions if needed - can be overridden by child classes

# Virtual methods to be overridden by child classes
func _setup_particle_appearance() -> void:
	# Override this method in child classes to set up custom appearance
	pass

func _should_collide_with(body: Node) -> bool:
	# Override this method in child classes to define collision behavior
	# Default implementation for basic surfaces
	return body is TileMap or body.is_in_group("walls") or body.is_in_group("ground")

func _on_collision(body: Node) -> void:
	# Override this method in child classes to handle collision effects
	# Default implementation does nothing
	pass

# Cleanup when particle is removed from scene tree
func _exit_tree() -> void:
	# Remove from batch processing system
	if is_batch_processing_enabled:
		Particle.active_particles.erase(self)
