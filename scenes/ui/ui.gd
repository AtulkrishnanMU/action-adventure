extends CanvasLayer

const HEALTH_HIGH_COLOR = Color(0.2, 0.8, 0.2, 1)  # Green for high health (>50%)
const HEALTH_MEDIUM_COLOR = Color(0.8, 0.8, 0.2, 1)  # Yellow for medium health (<50%)
const HEALTH_LOW_COLOR = Color(0.8, 0.2, 0.2, 1)  # Red for low health (<20%)
const HEALTH_MEDIUM_THRESHOLD = 0.5  # Below this percentage = yellow
const HEALTH_LOW_THRESHOLD = 0.2   # Below this percentage = red
const TRANSITION_DURATION = 0.3  # Duration for smooth transitions

var health_tween: Tween
var health_label: Label

# Cached style boxes to avoid recreation
var cached_fill_styles: Dictionary = {}
var current_health_state: String = "high"

func _ready():
	# Find the health bar and labels
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.show_percentage = false
		health_label = health_bar.get_node_or_null("HealthLabel")
		
		# Initialize cached style boxes
		_initialize_cached_styles()
		
		# Set initial health bar color to high health color
		_update_fill_color("high")
	
	# Add to ui group for player communication
	add_to_group("ui")

# Initialize cached style boxes to avoid recreation
func _initialize_cached_styles() -> void:
	# Create style boxes for each health state
	cached_fill_styles["high"] = _create_fill_style(HEALTH_HIGH_COLOR)
	cached_fill_styles["medium"] = _create_fill_style(HEALTH_MEDIUM_COLOR)
	cached_fill_styles["low"] = _create_fill_style(HEALTH_LOW_COLOR)

# Create a reusable fill style with given color
func _create_fill_style(color: Color) -> StyleBoxFlat:
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.border_width_left = 2
	fill_style.border_width_right = 2
	fill_style.border_width_top = 2
	fill_style.border_width_bottom = 2
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	return fill_style

func update_health(current: int, max_health: int):
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.max_value = max_health
		
		# Update health label text
		if health_label:
			health_label.text = str(current) + "/" + str(max_health) + " HP"
		
		# Create smooth transition
		if health_tween and health_tween.is_valid():
			health_tween.kill()
		
		health_tween = create_tween()
		health_tween.set_ease(Tween.EASE_IN_OUT)
		health_tween.set_trans(Tween.TRANS_SINE)
		health_tween.tween_property(health_bar, "value", current, TRANSITION_DURATION)
		
		_update_color(current, max_health)

func _update_color(current: int, max_health: int):
	var health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		return
		
	var health_percentage = float(current) / float(max_health)
	var target_state = "high"
	
	if health_percentage <= HEALTH_LOW_THRESHOLD:
		target_state = "low"
	elif health_percentage <= HEALTH_MEDIUM_THRESHOLD:
		target_state = "medium"
	
	# Only update if state actually changed
	if target_state != current_health_state:
		# Smooth color transition using cached styles
		if health_tween and health_tween.is_valid():
			var current_color = cached_fill_styles[current_health_state].bg_color
			var target_color = cached_fill_styles[target_state].bg_color
			health_tween.parallel().tween_method(_interpolate_fill_color, current_color, target_color, TRANSITION_DURATION)
		else:
			_update_fill_color(target_state)
		current_health_state = target_state

# Interpolate between colors for smooth transition
func _interpolate_fill_color(color: Color):
	var health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		return
		
	# Update current cached style's color temporarily
	var current_style = cached_fill_styles[current_health_state]
	current_style.bg_color = color
	health_bar.add_theme_stylebox_override("fill", current_style)

func _update_fill_color(state: String):
	var health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		return
		
	# Use cached style box instead of creating new one
	if cached_fill_styles.has(state):
		health_bar.add_theme_stylebox_override("fill", cached_fill_styles[state])
	else:
		# Fallback - create style if not cached
		var color = HEALTH_HIGH_COLOR
		if state == "medium":
			color = HEALTH_MEDIUM_COLOR
		elif state == "low":
			color = HEALTH_LOW_COLOR
		
		var fill_style = _create_fill_style(color)
		health_bar.add_theme_stylebox_override("fill", fill_style)
