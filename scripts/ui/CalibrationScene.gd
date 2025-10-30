extends Control

## ============================================================================
## CALIBRATION SCENE - PRE-GAME TIMING ADJUSTMENT
## ============================================================================
## Industry standard approach: calibrate BEFORE gameplay, not during.
##
## How it works:
## 1. Play simple 120 BPM test pattern
## 2. Player taps in rhythm with beats
## 3. Calculate average offset from taps
## 4. Save offset to GameManager
## 5. Return to menu
##
## Never adjust timing mid-game - it creates visual discontinuity.
## ============================================================================

@onready var audio_player := AudioStreamPlayer.new()
@onready var visual_indicator := ColorRect.new()
@onready var result_label := Label.new()
@onready var instruction_label := Label.new()
@onready var tap_counter_label := Label.new()

# Calibration state
var calibration_offset: float = 0.0  # milliseconds
var tap_times: Array[float] = []
var beat_offsets: Array[float] = []
var is_recording: bool = false
var min_taps_required: int = 8

# Timing
var sec_per_beat: float = 0.5  # 120 BPM
var current_beat: float = 0.0

func _ready():
	# Set up UI layout
	setup_ui()

	# Add audio player
	add_child(audio_player)

	# Load calibration audio (simple metronome or beat)
	# TODO: Create a simple metronome audio file at 120 BPM
	# For now, we'll use visual-only calibration

	# Start visual indicator
	is_recording = true
	instruction_label.text = "Tap any key (1-5) in rhythm with the pulsing circle.\nNeed at least 8 taps for calibration."

func setup_ui():
	"""Create calibration UI elements."""
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.1, 1.0)
	bg.size = get_viewport().get_visible_rect().size
	add_child(bg)

	# Instruction label (top)
	instruction_label.position = Vector2(960, 200)
	instruction_label.size = Vector2(800, 100)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.add_theme_font_size_override("font_size", 24)
	instruction_label.add_theme_color_override("font_color", Color.WHITE)
	instruction_label.text = "Loading..."
	add_child(instruction_label)

	# Visual indicator (center)
	visual_indicator.position = Vector2(860, 440)
	visual_indicator.size = Vector2(200, 200)
	visual_indicator.color = Color.CYAN
	add_child(visual_indicator)

	# Tap counter (below indicator)
	tap_counter_label.position = Vector2(960, 680)
	tap_counter_label.size = Vector2(400, 50)
	tap_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_counter_label.add_theme_font_size_override("font_size", 32)
	tap_counter_label.add_theme_color_override("font_color", Color.YELLOW)
	tap_counter_label.text = "Taps: 0 / " + str(min_taps_required)
	add_child(tap_counter_label)

	# Result label (bottom)
	result_label.position = Vector2(960, 850)
	result_label.size = Vector2(800, 100)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 28)
	result_label.add_theme_color_override("font_color", Color.GREEN)
	result_label.text = ""
	add_child(result_label)

func _process(delta):
	if not is_recording:
		return

	# Update current beat
	current_beat += delta / sec_per_beat

	# Pulse visual indicator on beats
	var beat_progress = fmod(current_beat, 1.0)
	var scale_factor = 1.0 + (1.0 - beat_progress) * 0.5
	visual_indicator.scale = Vector2(scale_factor, scale_factor)

	# Change color briefly on beat
	if beat_progress < 0.1:
		visual_indicator.color = Color.WHITE
	else:
		visual_indicator.color = Color.CYAN

func _input(event):
	if not is_recording:
		# After calibration, space to continue
		if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			if result_label.text != "":
				return_to_menu()
		return

	if event is InputEventKey and event.pressed:
		# Accept keys 1-5 for taps
		if event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]:
			record_tap()

func record_tap():
	"""Record a tap and calculate offset from nearest beat."""
	# Get current time in beats
	var beat = fmod(current_beat, 1.0)

	# Find nearest beat (0.0 or 1.0)
	var nearest_beat_offset = beat
	if beat > 0.5:
		nearest_beat_offset = beat - 1.0

	# Convert to milliseconds
	var offset_ms = nearest_beat_offset * sec_per_beat * 1000.0

	# Store this tap
	beat_offsets.append(offset_ms)

	# Update tap counter
	tap_counter_label.text = "Taps: " + str(beat_offsets.size()) + " / " + str(min_taps_required)

	# Flash indicator on tap
	visual_indicator.color = Color.YELLOW
	await get_tree().create_timer(0.1).timeout
	visual_indicator.color = Color.CYAN

	# Check if we have enough taps
	if beat_offsets.size() >= min_taps_required:
		calculate_calibration()

func calculate_calibration():
	"""Calculate average offset from taps."""
	is_recording = false

	# Remove outliers (anything > 150ms off)
	var valid_offsets: Array[float] = []
	for offset in beat_offsets:
		if abs(offset) < 150.0:
			valid_offsets.append(offset)

	# Calculate average
	if valid_offsets.size() >= 5:
		var sum: float = 0.0
		for offset in valid_offsets:
			sum += offset

		calibration_offset = sum / valid_offsets.size()

		# Save to GameManager
		GameManager.set_setting("rhythm_timing_offset", int(calibration_offset))

		# Show result
		result_label.text = "Calibration: %+.1f ms\n\nPress SPACE to continue" % calibration_offset
		instruction_label.text = "Calibration complete!"

		# Stop pulsing
		visual_indicator.color = Color.GREEN
	else:
		# Not enough valid taps
		result_label.text = "Not enough valid taps. Try again.\n\nPress SPACE to retry"
		instruction_label.text = "Too many mistimed taps!"
		visual_indicator.color = Color.RED

func return_to_menu():
	"""Return to main menu or previous scene."""
	# TODO: Change to appropriate scene
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func _on_skip_button_pressed():
	"""Skip calibration and return to menu."""
	return_to_menu()
