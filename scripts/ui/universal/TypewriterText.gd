extends Control
class_name TypewriterText

## ============================================================================
## TYPEWRITER TEXT COMPONENT
## ============================================================================
## Reusable component for narrative text display with typewriter effect.
##
## Features:
## - Character-by-character typing animation
## - Auto-advance after delay when typing completes
## - Click to fast-forward typing
## - Click again to skip to next message instantly
## - Centered text in 1000px container with auto-wrapping
## - Procedural audio tones (random notes, highest at end)
## ============================================================================

signal typing_complete
signal advance_requested

# Text configuration
@export var text_content: String = ""
@export var typing_speed: float = 0.03  # Seconds per character
@export var auto_advance_delay: float = 3.0  # Seconds after typing completes
@export var max_width: int = 1000
@export var font_size: int = 100  # Font size in pixels

# Audio configuration
@export var enable_audio: bool = true
@export var min_frequency: float = 300.0  # Lowest random tone
@export var max_frequency: float = 600.0  # Highest random tone
@export var final_frequency: float = 800.0  # Final character tone
@export var tone_duration: float = 0.05  # Duration of each beep

# UI elements
var label: Label
var container: CenterContainer
var audio_player: AudioStreamPlayer
var audio_generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback

# State
var current_char_index: int = 0
var is_typing: bool = false
var typing_complete_flag: bool = false
var auto_advance_timer: float = 0.0
var full_text: String = ""
var char_timer: float = 0.0

func _ready():
	# Create container for centering
	container = CenterContainer.new()
	container.size = get_viewport().get_visible_rect().size
	container.position = Vector2.ZERO
	add_child(container)

	# Create label inside container
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(max_width, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Style the label (white pixel font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)

	container.add_child(label)

	# Setup audio generator for procedural tones
	if enable_audio:
		_setup_audio_generator()

	# Set initial text
	if text_content != "":
		set_text(text_content)

func set_text(new_text: String):
	"""Set new text and start typing animation."""
	full_text = new_text
	current_char_index = 0
	is_typing = true
	typing_complete_flag = false
	auto_advance_timer = 0.0
	label.text = ""

func _process(delta):
	if is_typing:
		_type_next_character(delta)
	elif typing_complete_flag:
		# Auto-advance timer after typing completes
		auto_advance_timer += delta
		if auto_advance_timer >= auto_advance_delay:
			emit_signal("advance_requested")

func _type_next_character(delta):
	"""Type one character at a time."""
	if current_char_index >= full_text.length():
		is_typing = false
		typing_complete_flag = true
		emit_signal("typing_complete")
		return

	# Simple timing (not perfect but sufficient)
	char_timer += delta

	if char_timer >= typing_speed:
		char_timer = 0.0
		label.text += full_text[current_char_index]
		current_char_index += 1

		# Play audio tone for character
		if enable_audio:
			_play_character_tone()

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		_handle_click()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_handle_click()

func _handle_click():
	"""Handle player input to fast-forward or advance."""
	if is_typing:
		# Fast-forward: complete typing instantly
		label.text = full_text
		current_char_index = full_text.length()
		is_typing = false
		typing_complete_flag = true
		emit_signal("typing_complete")
	elif typing_complete_flag:
		# Advance: skip to next message
		emit_signal("advance_requested")

func reset():
	"""Reset the component for reuse."""
	label.text = ""
	current_char_index = 0
	is_typing = false
	typing_complete_flag = false
	auto_advance_timer = 0.0
	full_text = ""

func _setup_audio_generator():
	"""Initialize procedural audio generator for typing sounds."""
	# Create audio stream generator
	audio_generator = AudioStreamGenerator.new()
	audio_generator.mix_rate = 22050  # Low mix rate for efficiency
	audio_generator.buffer_length = 0.1  # Short buffer for low latency

	# Create audio player
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio_generator
	audio_player.bus = "SFX"
	add_child(audio_player)

	# Start playback to get playback instance
	audio_player.play()
	playback = audio_player.get_stream_playback()

func _play_character_tone():
	"""Play a procedural tone for the current character."""
	if not playback:
		return

	# Determine if this is the last character
	var is_last_char = (current_char_index >= full_text.length())

	# Choose frequency: random for all but last, highest for last
	var frequency = final_frequency if is_last_char else randf_range(min_frequency, max_frequency)

	# Generate tone samples
	var sample_count = int(audio_generator.mix_rate * tone_duration)
	var increment = frequency / audio_generator.mix_rate

	for i in range(sample_count):
		# Generate sine wave sample
		var phase = i * increment
		var sample = sin(phase * TAU)

		# Apply envelope (fade out to prevent clicks)
		var envelope = 1.0
		if i > sample_count * 0.7:
			envelope = 1.0 - ((i - sample_count * 0.7) / (sample_count * 0.3))

		# Push stereo frame
		playback.push_frame(Vector2(sample * envelope * 0.3, sample * envelope * 0.3))
