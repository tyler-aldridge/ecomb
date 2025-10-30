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
var is_warning_active: bool = false
var warning_color_tween: Tween = null
var warning_scale_tween: Tween = null
var tutorial_highlight_tween: Tween = null

# Cache stylebox to avoid expensive get_theme_stylebox() every frame
var cached_fill_style: StyleBoxFlat = null

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

		# Cache fill stylebox once to avoid expensive lookups every frame
		var fill_style = progress_bar.get_theme_stylebox("fill")
		if fill_style and fill_style is StyleBoxFlat:
			cached_fill_style = fill_style

		# Set initial color to green (50%)
		update_bar_color(50.0)

func _process(delta):
	if not is_full:
		return

	# Calculate BPM-based animation speeds
	var bpm = BattleManager.current_bpm if BattleManager else 120.0
	var half_bpm_rate = (bpm / 60.0) / 2.0

	# Rainbow animation on bar when full (tied to half BPM)
	if cached_fill_style:
		rainbow_time += delta * half_bpm_rate
		if rainbow_time >= rainbow_colors.size():
			rainbow_time = 0.0

		var current_index = int(rainbow_time) % rainbow_colors.size()
		var next_index = (current_index + 1) % rainbow_colors.size()
		var t = rainbow_time - floor(rainbow_time)
		cached_fill_style.bg_color = rainbow_colors[current_index].lerp(rainbow_colors[next_index], t)

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	current_percentage = percentage

	# Check if full for rainbow pulsing
	var was_full = is_full
	is_full = percentage >= 100.0

	# Start rainbow on green (index 3) for smooth UX transition from 100% green
	if is_full and not was_full:
		rainbow_time = 3.0  # Start at green in rainbow_colors array

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
	if not cached_fill_style:
		return

	if percentage <= 49.0:
		# Yellow for 49% and below
		cached_fill_style.bg_color = yellow_color
	elif percentage >= 50.0 and percentage < 100.0:
		# Smooth transition from yellow to green between 49-51%
		if percentage < 51.0:
			var t = (percentage - 49.0) / 2.0  # 0.0 at 49%, 1.0 at 51%
			cached_fill_style.bg_color = yellow_color.lerp(green_color, t)
		else:
			cached_fill_style.bg_color = green_color

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

func _exit_tree():
	"""Ensure all infinite loop tweens are properly cleaned up when node is removed."""
	stop_low_groove_warning()

func set_groove(percentage: float):
	"""Manually set groove percentage (for tutorials)."""
	if not progress_bar:
		return
	progress_bar.value = percentage
	current_percentage = percentage
	update_bar_color(percentage)

func set_tutorial_highlight(enabled: bool):
	"""Enable/disable yellow flashing border for tutorial."""
	if not cached_fill_style:
		return

	if enabled:
		# Set border to 10px and start yellow flashing
		cached_fill_style.border_width_left = 10
		cached_fill_style.border_width_top = 10
		cached_fill_style.border_width_right = 10
		cached_fill_style.border_width_bottom = 10

		# Create flashing yellow animation (infinite loop)
		tutorial_highlight_tween = create_tween()
		tutorial_highlight_tween.set_loops()
		tutorial_highlight_tween.tween_property(cached_fill_style, "border_color", Color(1, 1, 0, 0.3), 0.5).set_ease(Tween.EASE_IN_OUT)
		tutorial_highlight_tween.tween_property(cached_fill_style, "border_color", Color(1, 1, 0, 1.0), 0.5).set_ease(Tween.EASE_IN_OUT)
	else:
		# Stop the flashing animation
		if tutorial_highlight_tween:
			tutorial_highlight_tween.kill()
			tutorial_highlight_tween = null

		# Reset border to default
		cached_fill_style.border_width_left = 5
		cached_fill_style.border_width_top = 5
		cached_fill_style.border_width_right = 5
		cached_fill_style.border_width_bottom = 5
		cached_fill_style.border_color = Color(1, 1, 1, 1)