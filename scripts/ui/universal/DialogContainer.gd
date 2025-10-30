extends PanelContainer

# Animated rainbow border for dialog boxes
# Creates a "snake" effect by cycling through rainbow colors

var rainbow_time: float = 0.0
var rainbow_colors = [
	Color(1, 0, 0, 1),      # Red
	Color(1, 0.5, 0, 1),    # Orange
	Color(1, 1, 0, 1),      # Yellow
	Color(0, 1, 0, 1),      # Green
	Color(0, 1, 1, 1),      # Cyan
	Color(0, 0, 1, 1),      # Blue
	Color(0.56, 0, 1, 1)    # Violet
]

# Cache the stylebox to avoid get_theme_stylebox() every frame (expensive!)
var cached_style: StyleBoxFlat = null

# Audio for typing effect
var audio_player: AudioStreamPlayer
var audio_generator: AudioStreamGenerator
var playback: AudioStreamGeneratorPlayback
var enable_audio: bool = true
var min_frequency: float = 300.0
var max_frequency: float = 600.0
var final_frequency: float = 800.0
var tone_duration: float = 0.05

func _ready():
	# Cache stylebox once at start instead of every frame
	var style = get_theme_stylebox("panel")
	if style and style is StyleBoxFlat:
		cached_style = style

	# Setup audio generator for typing sounds
	if enable_audio:
		_setup_audio_generator()

func _input(event):
	"""Allow clicking or spacebar to skip typing animation."""
	if event is InputEventMouseButton and event.pressed:
		# Signal to DialogManager to skip typing
		get_tree().root.set_meta("skip_dialog_typing", true)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# Signal to DialogManager to skip typing
		get_tree().root.set_meta("skip_dialog_typing", true)

func _process(delta):
	# Only animate if we have a valid cached style
	if not cached_style:
		return

	# Animate rainbow border
	rainbow_time += delta * 2.0  # Speed of color cycling
	if rainbow_time >= rainbow_colors.size():
		rainbow_time = 0.0

	var color_index = int(rainbow_time)
	var next_index = (color_index + 1) % rainbow_colors.size()
	var t = rainbow_time - floor(rainbow_time)
	cached_style.border_color = rainbow_colors[color_index].lerp(rainbow_colors[next_index], t)

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
	audio_player.volume_db = -10.0  # Lower volume by 10dB
	add_child(audio_player)

	# Start playback to get playback instance
	audio_player.play()
	playback = audio_player.get_stream_playback()

func play_character_tone(is_last_char: bool = false):
	"""Play a procedural tone for a typed character."""
	if not enable_audio or not playback:
		return

	# Choose frequency: random for all but last, highest for last
	var frequency = final_frequency if is_last_char else randf_range(min_frequency, max_frequency)

	# Generate tone samples
	var sample_count = int(audio_generator.mix_rate * tone_duration)
	var increment = frequency / audio_generator.mix_rate

	for i in range(sample_count):
		# Generate square wave sample (switches between -1 and 1)
		var phase = i * increment
		var sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0

		# Apply envelope (fade out to prevent clicks)
		var envelope = 1.0
		if i > sample_count * 0.7:
			envelope = 1.0 - ((i - sample_count * 0.7) / (sample_count * 0.3))

		# Push stereo frame
		playback.push_frame(Vector2(sample * envelope * 0.3, sample * envelope * 0.3))
