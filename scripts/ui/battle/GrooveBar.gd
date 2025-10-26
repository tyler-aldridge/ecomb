extends Control

# ============================================================================
# GROOVE BAR - Universal Battle Health System
# ============================================================================
# Displays groove with yellow (≤49%) to green (≥50%) gradient
# - Rainbow pulsing when full
# - Smooth color transitions
# - Rounded right side
# - Z-indexed to top
# - Tutorial message that pulses from center

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var tutorial_message: Label = $TutorialMessage

var current_percentage: float = 50.0
var rainbow_time: float = 0.0
var is_full: bool = false
var pulse_time: float = 0.0

# Rainbow colors for full groove pulse
var rainbow_colors = [
	Color(1, 0, 0, 1),      # Red
	Color(1, 0.5, 0, 1),    # Orange
	Color(1, 1, 0, 1),      # Yellow
	Color(0, 1, 0, 1),      # Green
	Color(0, 1, 1, 1),      # Cyan
	Color(0, 0, 1, 1),      # Blue
	Color(0.56, 0, 1, 1)    # Violet
]

# Yellow to green gradient colors
var yellow_color = Color(1, 1, 0, 1)  # Yellow for ≤49%
var green_color = Color(0, 1, 0, 1)    # Green for ≥50%

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)
		BattleManager.show_groove_tutorial.connect(show_tutorial_message)
		BattleManager.hide_groove_tutorial.connect(hide_tutorial_message)

	# Initialize progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50
		# Set initial color to green (50%)
		update_bar_color(50.0)

func _process(delta):
	if is_full:
		# Rainbow pulse animation on bar when full
		if progress_bar:
			rainbow_time += delta * 4.0
			if rainbow_time >= rainbow_colors.size():
				rainbow_time = 0.0

			var fill_style = progress_bar.get_theme_stylebox("fill")
			if fill_style and fill_style is StyleBoxFlat:
				var color_index = int(rainbow_time)
				var next_index = (color_index + 1) % rainbow_colors.size()
				var t = rainbow_time - floor(rainbow_time)
				fill_style.bg_color = rainbow_colors[color_index].lerp(rainbow_colors[next_index], t)

	# Pulsing animation for tutorial message when visible
	if tutorial_message and tutorial_message.visible:
		pulse_time += delta * 2.0
		var scale_value = 1.0 + sin(pulse_time) * 0.15  # Pulse between 0.85 and 1.15
		tutorial_message.scale = Vector2(scale_value, scale_value)

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	current_percentage = percentage

	# Check if full for rainbow pulsing
	is_full = percentage >= 100.0

	# Animate the value change with smooth easing
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", percentage, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Update color based on groove level
	if not is_full:
		update_bar_color(percentage)

	# Play warning animation if low
	if percentage < 25.0:
		play_low_groove_warning()

func update_bar_color(percentage: float):
	"""Update bar fill color: yellow for ≤49%, green for ≥50%, smooth transition."""
	if not progress_bar:
		return

	var fill_style = progress_bar.get_theme_stylebox("fill")
	if fill_style and fill_style is StyleBoxFlat:
		if percentage <= 49.0:
			# Yellow for 49% and below
			fill_style.bg_color = yellow_color
		elif percentage >= 50.0 and percentage < 100.0:
			# Smooth transition from yellow to green between 49-51%
			if percentage < 51.0:
				var t = (percentage - 49.0) / 2.0  # 0.0 at 49%, 1.0 at 51%
				fill_style.bg_color = yellow_color.lerp(green_color, t)
			else:
				fill_style.bg_color = green_color

func play_low_groove_warning():
	"""Play warning animation when groove is low."""
	# Create a pulsing effect
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate:a", 0.7, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func show_tutorial_message():
	"""Show the tutorial message with fade in animation."""
	if tutorial_message:
		tutorial_message.visible = true
		tutorial_message.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(tutorial_message, "modulate:a", 1.0, 0.5)

func hide_tutorial_message():
	"""Hide the tutorial message with fade out animation."""
	if tutorial_message:
		var tween = create_tween()
		tween.tween_property(tutorial_message, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func(): tutorial_message.visible = false)
