extends Node
class_name Conductor

## ============================================================================
## DSP TIME-BASED CONDUCTOR - INDUSTRY STANDARD ARCHITECTURE
## ============================================================================
## Core Principle: DSP time is the single source of truth
## - No beat signals (frame-rate dependent)
## - Exposes song_pos_in_beats as variable for polling
## - Position interpolation for notes (not velocity)
## - Validates timing for web platform corruption
## ============================================================================

# Audio player (child node)
@onready var music_player := AudioStreamPlayer.new()

# Timing configuration
@export var bpm: float = 152.0
@export var measures: int = 4
@export var time_signature_beats: int = 4
@export var time_signature_division: int = 4

# Timing state (READ ONLY - do not modify externally)
var song_position: float = 0.0  # Current audio time in seconds
var song_pos_in_beats: float = 0.0  # Current position in beats (POLL THIS)
var sec_per_beat: float = 0.0

# Internal timing tracking
var audio_start_dsp_time: float = 0.0
var prev_audio_time: float = 0.0
var beats_before_start: int = 28

# Time signature subdivision: 2 for simple meters (4/4, 3/4), 3 for compound meters (6/8, 9/8, 12/8)
var subdivision: int = 2

# Countdown phase tracking (before audio starts)
var in_countdown: bool = false
var countdown_start_time: float = 0.0  # Real time when countdown started
var countdown_duration: float = 0.0
var countdown_tick_interval: float = 0.0
var countdown_next_beat: float = 0.0

# Web platform validation
var is_web: bool = OS.has_feature("web")
var consecutive_invalid_frames: int = 0
const MAX_INVALID_FRAMES: int = 5

# Pause handling
var is_paused: bool = false
var pause_time: float = 0.0

func _ready() -> void:
	# Add to group so BattleOptionsMenu can find and pause us
	add_to_group("conductor")

	# CRITICAL: Use PROCESS_MODE_ALWAYS so we can control pause
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Validate BPM to prevent division by zero
	if bpm <= 0:
		push_error("Invalid BPM: " + str(bpm) + ". Defaulting to 120.")
		bpm = 120.0

	sec_per_beat = 60.0 / bpm

	# Create and add music player as child
	add_child(music_player)
	music_player.name = "MusicPlayer"

func _process(_delta: float) -> void:
	# Pause handling
	if is_paused:
		return

	# COUNTDOWN PHASE: Before audio starts (silent beat tracking)
	if in_countdown:
		# Use real time instead of delta accumulation for web accuracy
		var countdown_time_elapsed = (Time.get_ticks_msec() / 1000.0) - countdown_start_time

		# Check if countdown is complete - start audio at beat 0
		if countdown_time_elapsed >= countdown_duration:
			in_countdown = false
			music_player.play()
			audio_start_dsp_time = AudioServer.get_time_since_last_mix()
			song_pos_in_beats = 0.0
			return

		# Calculate countdown beat position (negative beats before start)
		song_pos_in_beats = -beats_before_start + (countdown_time_elapsed / countdown_tick_interval)
		return

	# PLAYING PHASE: Audio is playing, use DSP time
	if music_player.playing:
		# CRITICAL: Query DSP time with validation
		var playback_pos = music_player.get_playback_position()
		var time_since_mix = AudioServer.get_time_since_last_mix()
		var output_latency = AudioServer.get_output_latency()

		# Clamp time_since_mix to prevent wild jumps
		time_since_mix = clamp(time_since_mix, 0.0, 0.1)

		# Calculate current audio time
		var current_audio_time = playback_pos + time_since_mix - output_latency

		# Web-specific validation (aggressive)
		if is_web:
			# Check for corruption
			if current_audio_time < 0 or current_audio_time > 1000:
				consecutive_invalid_frames += 1
				if consecutive_invalid_frames > MAX_INVALID_FRAMES:
					_attempt_audio_recovery()
				return

			# Check for backwards time
			if current_audio_time < prev_audio_time:
				consecutive_invalid_frames += 1
				return

			# Check for unrealistic jumps
			var time_delta = current_audio_time - prev_audio_time
			if time_delta > 0.1:  # >100ms jump
				consecutive_invalid_frames += 1
				return

		# Valid frame
		consecutive_invalid_frames = 0
		prev_audio_time = current_audio_time

		# Apply user-configurable timing offset for manual calibration
		song_position = current_audio_time + GameManager.get_timing_offset()

		# Convert song_position to beats (floating point for smooth interpolation)
		# For tick-based compatibility: multiply by subdivision to get ticks
		song_pos_in_beats = (song_position / sec_per_beat) * subdivision

func _attempt_audio_recovery():
	"""Fallback timing recovery for corrupted web audio."""
	push_warning("Audio timing corruption detected, attempting recovery")

	# Last resort: use playback position only (less accurate but stable)
	var fallback_time = music_player.get_playback_position()

	if fallback_time > 0 and fallback_time < 1000:
		prev_audio_time = fallback_time
		consecutive_invalid_frames = 0

func play_with_beat_offset() -> void:
	"""Start playback with countdown phase (industry standard approach)."""
	# Initialize countdown phase with real time tracking
	in_countdown = true
	countdown_start_time = Time.get_ticks_msec() / 1000.0  # Current time in seconds
	countdown_tick_interval = sec_per_beat / float(subdivision)
	countdown_next_beat = -beats_before_start

	# Calculate total countdown duration
	countdown_duration = beats_before_start * countdown_tick_interval

	# _process will handle countdown and automatically start audio

func play_song(audio_stream: AudioStream):
	"""Load and play a song immediately (no countdown)."""
	music_player.stream = audio_stream
	music_player.play()
	audio_start_dsp_time = AudioServer.get_time_since_last_mix()

func pause():
	"""Pause playback and save current position."""
	if is_paused:
		return

	is_paused = true
	pause_time = song_position
	music_player.stream_paused = true

func resume():
	"""Resume playback from paused position."""
	if not is_paused:
		return

	is_paused = false
	music_player.stream_paused = false

	# Resync timing after resume
	audio_start_dsp_time = AudioServer.get_time_since_last_mix() - pause_time

func stop():
	"""Stop playback completely."""
	music_player.stop()
	is_paused = false
	in_countdown = false
	song_position = 0.0
	song_pos_in_beats = 0.0

# Active state (includes countdown phase + playing phase)
var is_active: bool:
	get:
		return in_countdown or music_player.playing

# Legacy compatibility properties
var playing: bool:
	get:
		return music_player.playing

var stream_paused: bool:
	get:
		return music_player.stream_paused
	set(value):
		music_player.stream_paused = value

var stream: AudioStream:
	get:
		return music_player.stream
	set(value):
		music_player.stream = value

# For tick-based compatibility (returns integer ticks)
var song_position_in_beats_float: float:
	get:
		return song_pos_in_beats

var song_position_in_beats: int:
	get:
		return int(song_pos_in_beats)

# Deprecated - kept for compatibility
var seconds_per_beat: float:
	get:
		return sec_per_beat
	set(value):
		sec_per_beat = value
