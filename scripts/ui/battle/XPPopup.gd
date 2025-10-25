extends Label

# ============================================================================
# XP POPUP - Shows XP gain floating text
# ============================================================================
# Displays "+5XP", "+10XP" etc.
# - White text for GOOD/OKAY hits
# - Rainbow text for PERFECT hits
# - Pops in with scale, floats up, then fades out
# Positioned ~100px above combo display

var is_perfect: bool = false
var xp_amount: int = 0

# Rainbow colors
var rainbow_colors = [
	Color(1, 0, 0, 1),    # Red
	Color(1, 0.5, 0, 1),  # Orange
	Color(1, 1, 0, 1),    # Yellow
	Color(0, 1, 0, 1),    # Green
	Color(0, 1, 1, 1),    # Cyan
	Color(0, 0, 1, 1),    # Blue
	Color(1, 0, 1, 1)     # Magenta
]
var color_index: float = 0.0

func _ready():
	# Start invisible
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)

func show_xp(amount: int, perfect: bool = false):
	"""Show XP popup with amount and color."""
	xp_amount = amount
	is_perfect = perfect

	# Update text
	text = "+%dXP" % amount

	# Set color
	if is_perfect:
		modulate = Color(1, 0, 0, 1)  # Start with red, will cycle in _process
	else:
		modulate = Color(1, 1, 1, 1)  # White

	# Animate popup
	play_popup_animation()

func _process(delta):
	# Rainbow color cycling for PERFECT hits
	if is_perfect and modulate.a > 0.0:
		color_index += delta * 5.0
		if color_index >= rainbow_colors.size():
			color_index = 0.0

		var color_a = rainbow_colors[int(color_index)]
		var color_b = rainbow_colors[int(color_index + 1) % rainbow_colors.size()]
		var t = color_index - floor(color_index)
		var rainbow_color = color_a.lerp(color_b, t)
		rainbow_color.a = modulate.a  # Preserve alpha
		modulate = rainbow_color

func play_popup_animation():
	"""Animate the popup: scale in, float up, fade out."""
	var start_pos = position
	var float_distance = -80.0  # Float up 80px

	var tween = create_tween()
	tween.set_parallel(true)

	# Scale in
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

	# Hold and start floating
	tween.chain()
	tween.tween_interval(0.3)

	# Float up and fade out
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", start_pos.y + float_distance, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)

	# Clean up after animation
	tween.chain()
	tween.tween_callback(func():
		position = start_pos
		scale = Vector2(0.5, 0.5)
		color_index = 0.0
	)
