extends AudioStreamPlayer
class_name Conductor

signal beat(position: int)
signal measure(position: int)

@export var bpm: float = 152.0
@export var measures: int = 4

var song_position: float = 0.0
var song_position_in_beats: int = 0
var seconds_per_beat: float
var last_reported_beat: int = 0
var beats_before_start: int = 28
var current_measure: int = 1
var cached_output_latency: float = 0.0
var latency_cache_timer: float = 0.0

# Countdown phase tracking (before audio starts)
var in_countdown: bool = false
var countdown_time_elapsed: float = 0.0
var countdown_duration: float = 0.0
var countdown_tick_interval: float = 0.0
var countdown_next_beat: int = 0

# Time signature subdivision: 2 for simple meters (4/4, 3/4, 7/4), 3 for compound meters (6/8, 9/8, 12/8)
# Controls how Conductor converts beats to ticks (eighth notes vs triplets)
var subdivision: int = 2

# Pause handling - simplified, no snapshots needed
# AudioStreamPlayer.stream_paused handles everything automatically

func _ready() -> void:
	# Add to group so BattleOptionsMenu can find and pause us
	add_to_group("conductor")

	# CRITICAL: Use PROCESS_MODE_ALWAYS so we can control pause via stream_paused
	# Without this, tree pause will pause the Conductor node itself, breaking audio pause/resume
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Validate BPM to prevent division by zero
	if bpm <= 0:
		push_error("Invalid BPM: " + str(bpm) + ". Defaulting to 120.")
		bpm = 120.0

	seconds_per_beat = 60.0 / bpm

	# Cache output latency once at start
	cached_output_latency = AudioServer.get_output_latency()

	# Safety: Web browsers sometimes report unrealistic latency values
	# If latency is suspiciously low (< 5ms), ignore it and rely on user timing offset
	if OS.has_feature("web") and cached_output_latency < 0.005:
		cached_output_latency = 0.0
		print("Conductor: Web latency detection unreliable, using user timing offset only")

func _physics_process(delta: float) -> void:
	# Simple pause handling - stream_paused stops playback automatically
	if stream_paused:
		return

	# COUNTDOWN PHASE: Before audio starts (silent beat tracking)
	if in_countdown:
		countdown_time_elapsed += delta

		# Fire beats at regular intervals until we reach beat 0
		# For 4/4 with 36 beats before start: fires beats -36 to -1, stops before 0
		while countdown_next_beat < 0:  # Stop BEFORE beat 0 (Bar 1 Beat 1)
			var beat_time = (countdown_next_beat - (-beats_before_start)) * countdown_tick_interval
			if countdown_time_elapsed >= beat_time:
				emit_signal("beat", countdown_next_beat)
				last_reported_beat = countdown_next_beat
				countdown_next_beat += 1
			else:
				break

		# Check if countdown is complete - start audio at beat 0 (Bar 1 Beat 1)
		if countdown_next_beat >= 0:
			var start_time = (countdown_next_beat - (-beats_before_start)) * countdown_tick_interval
			if countdown_time_elapsed >= start_time:
				in_countdown = false
				play()  # Start audio NOW - position 0.0 = beat 0 (Bar 1 Beat 1)
				# Audio-based timing will now take over and fire beat 0 and onwards
				return

	# PLAYING PHASE: Audio is playing, use position for timing
	if playing:
		# Refresh latency cache every second (not every frame)
		latency_cache_timer += delta
		if latency_cache_timer >= 1.0:
			cached_output_latency = AudioServer.get_output_latency()
			# Safety check for web unrealistic values
			if OS.has_feature("web") and cached_output_latency < 0.005:
				cached_output_latency = 0.0
			latency_cache_timer = 0.0

		# Get audio playback position using proper AudioServer timing (all platforms)
		var playback_pos = get_playback_position()
		var time_since_mix = AudioServer.get_time_since_last_mix()

		# Clamp time_since_mix to prevent wild jumps on any platform
		time_since_mix = min(time_since_mix, 0.1)

		# Standard timing calculation that works cross-platform
		# playback_pos = stream decode position (starts at 0.0 when play() is called)
		# time_since_mix = time since audio buffer sent to hardware
		# cached_output_latency = hardware/driver speaker delay
		song_position = playback_pos + time_since_mix - cached_output_latency

		# Apply user-configurable timing offset for manual calibration
		song_position += GameManager.get_timing_offset()

		# Convert song_position to beat ticks
		# Audio position 0.0 = beat 0 (Bar 1 Beat 1)
		# Formula: beat_position = (song_position / seconds_per_beat) * subdivision
		# Example: position 0.0 → 0, position 0.395s (1 beat @ 152 BPM) → 2
		song_position_in_beats = int((song_position / seconds_per_beat) * subdivision)
		_report_beat()

func _report_beat() -> void:
	if last_reported_beat < song_position_in_beats:
		emit_signal("beat", song_position_in_beats)
		last_reported_beat = song_position_in_beats
		emit_signal("measure", current_measure)
		if current_measure < measures:
			current_measure += 1
		else:
			current_measure = 1

func play_with_beat_offset() -> void:
	# Initialize countdown phase
	# Countdown happens in SILENCE, then audio starts at beat 0 (Bar 1 Beat 1)
	in_countdown = true
	countdown_time_elapsed = 0.0
	countdown_tick_interval = seconds_per_beat / float(subdivision)
	countdown_next_beat = -beats_before_start
	last_reported_beat = -beats_before_start - 1

	# Calculate total countdown duration for reference
	countdown_duration = beats_before_start * countdown_tick_interval

	# _physics_process will handle:
	# 1. Fire beats from -beats_before_start to -1 during countdown (silent)
	# 2. Call play() when countdown finishes at beat 0
	# 3. Switch to audio-based timing after play()

	# Audio will start at beat 0 where position 0.0 = beat 0 (Bar 1 Beat 1)
