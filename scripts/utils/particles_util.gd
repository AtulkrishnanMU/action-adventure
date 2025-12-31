extends RefCounted

static func _scaled_amount(speed: float, base_speed: float, default_amount: int, min_amount: int = 1, max_amount: int = 10_000) -> int:
	if default_amount <= 0:
		return 0
	if base_speed <= 0.0:
		return clampi(default_amount, min_amount, max_amount)
	var scale := (speed / base_speed)/2
	var amt := int(round(float(default_amount) * scale))
	return clampi(amt, min_amount, max_amount)

static func init_particles(dust_particles: GPUParticles2D, landing_right: GPUParticles2D, landing_left: GPUParticles2D) -> void:
	dust_particles.emitting = false
	landing_right.emitting = false
	landing_left.emitting = false

static func trigger_landing_burst(
		landing_right: GPUParticles2D,
		landing_left: GPUParticles2D,
		speed: float,
		base_speed: float,
		default_amount_right: int,
		default_amount_left: int
	) -> void:
	landing_right.amount = _scaled_amount(speed, base_speed, default_amount_right)
	landing_left.amount = _scaled_amount(speed, base_speed, default_amount_left)
	landing_right.restart()
	landing_right.emitting = true
	landing_left.restart()
	landing_left.emitting = true

static func update_jump_dust_timer(current_timer: float, delta: float) -> float:
	if current_timer <= 0.0:
		return 0.0
	current_timer -= delta
	if current_timer <= 0.0:
		return 0.0
	return current_timer

static func update_continuous_dust(
		dust_particles: GPUParticles2D,
		is_moving_horizontally: bool,
		on_floor: bool,
		jump_dust_timer: float,
		speed: float,
		base_speed: float,
		default_amount: int
	) -> void:
	var should_emit := (is_moving_horizontally and on_floor) or (jump_dust_timer > 0.0)
	if should_emit:
		var target_amount := _scaled_amount(speed, base_speed, default_amount)
		if not dust_particles.emitting:
			dust_particles.amount = target_amount
		else:
			# Avoid decreasing amount while emitting; it can cull existing particles abruptly.
			if target_amount > dust_particles.amount:
				dust_particles.amount = target_amount
		dust_particles.emitting = true
	else:
		if dust_particles.emitting:
			dust_particles.emitting = false
