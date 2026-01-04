extends Node2D
class_name ParticleBatchProcessor

# Batch processing for all particles to reduce physics overhead
func _ready() -> void:
	name = "ParticleBatchProcessor"
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Call the static batch processing method from Particle class
	if Particle.is_batch_processing_enabled:
		Particle._batch_process_particles(delta)
