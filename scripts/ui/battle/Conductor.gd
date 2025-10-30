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
var startup_offset: float = 0.0  # Offset applied during countdown phase

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
		# playback_pos = stream decode position
		# time_since_mix = time since audio buffer sent to hardware
		# cached_output_latency = hardware/driver speaker delay
		song_position = playback_pos + time_since_mix - cached_output_latency

		# Apply startup offset for countdown phase (negative time before audio starts)
		song_position += startup_offset

		# Apply user-configurable timing offset for manual calibration
		song_position += GameManager.get_timing_offset()

		# Convert song_position to ticks using time signature subdivision
		# subdivision = 2 for simple meters (quarter to eighth), 3 for compound (dotted quarter to triplet eighth)
		# Offset by 4 beats (4 * subdivision ticks) to align with countdown system
		song_position_in_beats = int((song_position / seconds_per_beat) * subdivision) - (4 * subdivision)
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
	# Calculate countdown offset: convert beats to seconds
	# This creates a negative time period before audio starts where beats fire for countdown
	var time_offset = (beats_before_start * seconds_per_beat) / float(subdivision)
	startup_offset = -time_offset  # Applied to song_position in _physics_process

	# Initialize beat tracking to start from countdown
	last_reported_beat = -beats_before_start - 1  # Start one beat before to ensure first beat fires

	# Start audio playback immediately
	# Beats will fire naturally from negative positions due to startup_offset
	play()
		
		
