extends Camera2D

@export var target_path: NodePath
@export var smoothing_speed: float = 5.0

var target: Node2D
var initial_y: float
var target_x: float = 0.0
var current_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
    if target_path:
        target = get_node(target_path)
        # Store the initial Y position to maintain it
        initial_y = global_position.y
        target_x = target.global_position.x
    else:
        push_warning("No target path set for HorizontalFollowCamera")

func _physics_process(delta: float) -> void:
    if not target:
        return
    
    # Update target X position
    target_x = lerp(target_x, target.global_position.x, smoothing_speed * delta)
    
    # Only update the X position of the camera to follow the target
    var target_position = Vector2(target_x, initial_y)
    
    # Apply the position change while preserving any existing offset (for camera shake)
    var current_offset = offset
    global_position = target_position
    offset = current_offset
