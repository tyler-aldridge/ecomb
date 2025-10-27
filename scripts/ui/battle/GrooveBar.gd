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

var current_percentage: float = 50.0
var rainbow_time: float = 0.0
var is_full: bool = false
var pulse_time: float = 0.0
var is_warning_active: bool = false
var warning_color_tween: Tween = null
var warning_scale_tween: Tween = null

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
	if percentage < 30.0:
		if not is_warning_active:
			play_low_groove_warning()
	else:
		stop_low_groove_warning()

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
	"""Play warning animation when groove is low - red pulse (loops indefinitely)."""
	if is_warning_active:
		return  # Already playing
	
	is_warning_active = true
	
	# Flash red and pulse scale - INFINITE LOOPS
	warning_color_tween = create_tween()
	warning_color_tween.set_loops(0)  # 0 = infinite loops
	warning_color_tween.tween_property(self, "modulate", Color(1, 0.2, 0.2, 1), 0.3)
	warning_color_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	
	# Scale pulse at the same time
	warning_scale_tween = create_tween()
	warning_scale_tween.set_loops(0)  # 0 = infinite loops
	warning_scale_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.3)
	warning_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func stop_low_groove_warning():
	"""Stop the warning animation when groove recovers."""
	if not is_warning_active:
		return
	
	is_warning_active = false
	
	# Kill ONLY the warning tweens, not all tweens
	if warning_color_tween and is_instance_valid(warning_color_tween):
		warning_color_tween.kill()
		warning_color_tween = null
	
	if warning_scale_tween and is_instance_valid(warning_scale_tween):
		warning_scale_tween.kill()
		warning_scale_tween = null
	
	# Reset to normal appearance
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(1.0, 1.0)
