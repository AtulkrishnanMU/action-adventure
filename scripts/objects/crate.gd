extends RigidBody2D

func _ready() -> void:
	# Essential physics properties (match wild-west project defaults)
	gravity_scale = 0.0  # No gravity - stays in place unless pushed
	mass = 1.0          # Default mass
	freeze = false      # Not frozen

func _on_body_entered(body):
	if body.name == "Player":
		prints(name, "collided with player")
