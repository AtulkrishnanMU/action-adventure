extends RefCounted
class_name RNGUtils

# Shared random number generator to avoid repeated instantiation
static var _rng: RandomNumberGenerator
static var _initialized: bool = false

# Get or create the shared RNG instance
static func get_rng() -> RandomNumberGenerator:
	if not _initialized:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
		_initialized = true
	return _rng

# Convenience methods for common random operations
static func randi_range(from: int, to: int) -> int:
	return get_rng().randi_range(from, to)

static func randf_range(from: float, to: float) -> float:
	return get_rng().randf_range(from, to)

static func randf() -> float:
	return get_rng().randf()

static func randi() -> int:
	return get_rng().randi()

# Re-seed the RNG (useful for testing or reproducible scenarios)
static func seed_random(seed: int) -> void:
	get_rng().seed = seed
