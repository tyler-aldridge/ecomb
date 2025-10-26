extends Label

# ============================================================================
# COMBO DISPLAY - Shows current combo and multiplier
# ============================================================================
# Displays "Combo: 0x" format
# - White at 0x
# - Rainbow gradient with flag wave animation when > 0x
# - Flash and scale tween on combo increase
# Positioned 50px above player sprite

var combo_current: int = 0
var multiplier_current: float = 1.0

# Rainbow colors for cycling
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
var wave_offset: float = 0.0

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.combo_changed.connect(_on_combo_changed)
		BattleManager.combo_milestone_reached.connect(_on_combo_milestone)

	# Initialize
	update_display()

func _process(delta):
	# Animate rainbow and flag wave when combo > 0
	if combo_current > 0:
		# Cycle through rainbow colors
		color_index += delta * 3.0  # Speed of color change
		if color_index >= rainbow_colors.size():
			color_index = 0.0

		var color_a = rainbow_colors[int(color_index)]
		var color_b = rainbow_colors[int(color_index + 1) % rainbow_colors.size()]
		var t = color_index - floor(color_index)
		modulate = color_a.lerp(color_b, t)

		# Flag wave effect (subtle position offset)
		wave_offset += delta * 5.0
		rotation = sin(wave_offset) * 0.05  # Slight rotation wave

func _on_combo_changed(current_combo: int, multiplier: float):
	"""Update combo display when combo changes."""
	var old_combo = combo_current
	combo_current = current_combo
	multiplier_current = multiplier

	update_display()

	# Show/hide based on combo value
	if current_combo > 0:
		visible = true
		# Flash and scale animation on combo increase
		if current_combo > old_combo:
			play_combo_increase_animation()
	else:
		# Hide when combo is 0
		visible = false
		# Reset to white when combo breaks
		modulate = Color(1, 1, 1, 1)
		rotation = 0.0
		scale = Vector2(1, 1)

func update_display():
	"""Update the label text."""
	if multiplier_current > 1.0:
		text = "Combo %.1fx" % multiplier_current
	else:
		text = "Combo %dx" % combo_current

	# Set to white if no combo
	if combo_current == 0:
		modulate = Color(1, 1, 1, 1)

func play_combo_increase_animation():
	"""Flash and scale when combo increases."""
	# Flash bright
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	flash_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _on_combo_milestone(_combo: int, _multiplier: float):
	"""Extra celebration for milestones (10, 20, 30, 40)."""
	# Big scale bounce
	var milestone_tween = create_tween()
	milestone_tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	milestone_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN_OUT)
