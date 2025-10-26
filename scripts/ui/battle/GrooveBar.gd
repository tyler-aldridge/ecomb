extends Control

# ============================================================================
# GROOVE BAR - Universal Battle Health System
# ============================================================================
# Displays groove as a solid color progress bar with bevel design
# - Cyan fill color
# - Grey background
# - Smooth animations on value change
# - Z-indexed to top

@onready var progress_bar: ProgressBar = $ProgressBar

var current_percentage: float = 50.0

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	current_percentage = percentage

	# Animate the value change with smooth easing
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", percentage, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Update color based on groove level
	update_bar_color(percentage)

	# Play warning animation if low
	if percentage < 25.0:
		play_low_groove_warning()

func update_bar_color(percentage: float):
	"""Update bar fill color based on groove level."""
	if not progress_bar:
		return

	var fill_style = progress_bar.get_theme_stylebox("fill")
	if fill_style and fill_style is StyleBoxFlat:
		if percentage >= 50.0:
			# High groove: Cyan
			fill_style.bg_color = Color(0, 0.7, 1, 1)
		elif percentage >= 25.0:
			# Medium groove: Yellow
			fill_style.bg_color = Color(1, 0.9, 0, 1)
		else:
			# Low groove: Red
			fill_style.bg_color = Color(1, 0.2, 0.2, 1)

func play_low_groove_warning():
	"""Play warning animation when groove is low."""
	# Create a pulsing effect
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate:a", 0.7, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
