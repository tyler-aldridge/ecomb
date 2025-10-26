extends Control

# ============================================================================
# GROOVE BAR - Universal Battle Health System
# ============================================================================
# Displays groove as ROYGBIV gradient progress bar
# - Rainbow pulsing when full
# - ROYGBIV static gradient based on percentage
# - Rounded right side
# - Z-indexed to top

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var groove_label: Label = $GrooveLabel

var current_percentage: float = 50.0
var rainbow_time: float = 0.0
var is_full: bool = false

# ROYGBIV colors
var roygbiv_colors = [
	Color(1, 0, 0, 1),      # Red
	Color(1, 0.5, 0, 1),    # Orange
	Color(1, 1, 0, 1),      # Yellow
	Color(0, 1, 0, 1),      # Green
	Color(0, 0, 1, 1),      # Blue
	Color(0.29, 0, 0.51, 1), # Indigo
	Color(0.56, 0, 1, 1)    # Violet
]

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50
		# Set initial color to green (50%)
		update_bar_color(50.0)

func _process(delta):
	# Rainbow pulse animation when groove is full
	if is_full and progress_bar:
		rainbow_time += delta * 3.0
		if rainbow_time >= roygbiv_colors.size():
			rainbow_time = 0.0

		var fill_style = progress_bar.get_theme_stylebox("fill")
		if fill_style and fill_style is StyleBoxFlat:
			var color_index = int(rainbow_time)
			var next_index = (color_index + 1) % roygbiv_colors.size()
			var t = rainbow_time - floor(rainbow_time)
			fill_style.bg_color = roygbiv_colors[color_index].lerp(roygbiv_colors[next_index], t)

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	current_percentage = percentage

	# Update label text
	if groove_label:
		groove_label.text = "Groove %d%%" % int(percentage)

	# Check if full for rainbow pulsing
	is_full = percentage >= 100.0

	# Animate the value change with smooth easing
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", percentage, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Update color based on groove level (ROYGBIV gradient)
	if not is_full:
		update_bar_color(percentage)

	# Play warning animation if low
	if percentage < 25.0:
		play_low_groove_warning()

func update_bar_color(percentage: float):
	"""Update bar fill color based on groove level using ROYGBIV gradient."""
	if not progress_bar:
		return

	var fill_style = progress_bar.get_theme_stylebox("fill")
	if fill_style and fill_style is StyleBoxFlat:
		# Map percentage (0-100) to ROYGBIV colors (0-6 indices)
		var color_position = (percentage / 100.0) * (roygbiv_colors.size() - 1)
		var color_index = int(color_position)
		var next_index = min(color_index + 1, roygbiv_colors.size() - 1)
		var t = color_position - floor(color_position)

		fill_style.bg_color = roygbiv_colors[color_index].lerp(roygbiv_colors[next_index], t)

func play_low_groove_warning():
	"""Play warning animation when groove is low."""
	# Create a pulsing effect
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate:a", 0.7, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
