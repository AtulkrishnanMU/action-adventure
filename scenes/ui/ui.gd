extends CanvasLayer

const HEALTH_HIGH_COLOR = Color(0.2, 0.8, 0.2, 1)  # Green for high health (>50%)
const HEALTH_MEDIUM_COLOR = Color(0.8, 0.8, 0.2, 1)  # Yellow for medium health (<50%)
const HEALTH_LOW_COLOR = Color(0.8, 0.2, 0.2, 1)  # Red for low health (<20%)
const HEALTH_MEDIUM_THRESHOLD = 0.5  # Below this percentage = yellow
const HEALTH_LOW_THRESHOLD = 0.2   # Below this percentage = red
const TRANSITION_DURATION = 0.3  # Duration for smooth transitions

var health_tween: Tween
var health_label: Label

func _ready():
	# Find the health bar and labels
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.show_percentage = false
		health_label = health_bar.get_node_or_null("HealthLabel")
		
		# Set initial health bar color to high health color
		_update_fill_color(HEALTH_HIGH_COLOR)
	
	# Add to ui group for player communication
	add_to_group("ui")

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
	var target_color = HEALTH_HIGH_COLOR
	
	if health_percentage <= HEALTH_LOW_THRESHOLD:
		target_color = HEALTH_LOW_COLOR
	elif health_percentage <= HEALTH_MEDIUM_THRESHOLD:
		target_color = HEALTH_MEDIUM_COLOR
	
	# Smooth color transition
	if health_tween and health_tween.is_valid():
		health_tween.parallel().tween_method(_update_fill_color, health_bar.get_theme_stylebox("fill").bg_color, target_color, TRANSITION_DURATION)
	else:
		_update_fill_color(target_color)

func _update_fill_color(color: Color):
	var health_bar = get_node_or_null("HealthBar")
	if not health_bar:
		return
		
	# Create fresh style for fill
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
	health_bar.add_theme_stylebox_override("fill", fill_style)
