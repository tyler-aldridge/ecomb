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

# Pause sync safety: Track playback position drift during pause
var paused_song_position: float = 0.0
var paused_playback_position: float = 0.0
var was_stream_paused: bool = false
var pause_drift_offset: float = 0.0  # Accumulated drift to compensate for web audio buffer advancing during pause

var start_timer: Timer

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
	# NOTE: Web browsers often report incorrect/low latency values
	# Use user timing offset setting for accurate web compensation
	cached_output_latency = AudioServer.get_output_latency()
	if OS.has_feature("web") and cached_output_latency < 0.05:
		# Web latency detection often fails, rely on user timing offset instead
		cached_output_latency = 0.0

func _physics_process(delta: float) -> void:
	# CRITICAL: Detect pause state transitions to prevent timing drift
	if stream_paused and not was_stream_paused:
		# Entering paused state - capture positions to detect drift on unpause
		paused_song_position = song_position
		paused_playback_position = get_playback_position()
		was_stream_paused = true
		return
	elif stream_paused:
		# Already paused - keep song_position frozen
		song_position = paused_song_position
		return
	elif not stream_paused and was_stream_paused:
		# Exiting paused state - calculate drift and store as persistent offset
		was_stream_paused = false
		var current_playback_pos = get_playback_position()
		var drift = current_playback_pos - paused_playback_position
		# Accumulate drift to compensate in all future get_playback_position() calls
		# This prevents beat grid from shifting after pause/unpause
		pause_drift_offset += drift

	if playing:
		# Refresh latency cache every second (not every frame)
		latency_cache_timer += delta
		if latency_cache_timer >= 1.0:
			cached_output_latency = AudioServer.get_output_latency()
			# Web browsers often report incorrect latency, disable if unrealistic
			if OS.has_feature("web") and cached_output_latency < 0.05:
				cached_output_latency = 0.0
			latency_cache_timer = 0.0

		# Get audio playback position and apply pause drift compensation
		# NOTE: On web, browser audio buffering causes get_playback_position() to report
		# the stream decode position, which is ~0.5-1.0s BEHIND actual speaker output
		# Additionally, get_playback_position() may advance during pause, so we subtract accumulated drift
		var playback_pos = get_playback_position() - pause_drift_offset
		var time_since_mix = AudioServer.get_time_since_last_mix()

		# Web timing strategy: Use both playback_pos AND time_since_mix, plus buffer compensation
		if OS.has_feature("web"):
			# Clamp time_since_mix to prevent wild jumps
			time_since_mix = min(time_since_mix, 0.1)
			# On web, add ~800ms to compensate for browser audio buffer delay
			# Browser buffers audio ahead, so actual audio output is ahead of reported position
			song_position = playback_pos + time_since_mix + 0.8  # +800ms web buffer compensation
		else:
			# Desktop: use accurate timing with mix offset
			song_position = playback_pos + time_since_mix
			song_position -= cached_output_latency

		# Apply user-configurable timing offset for audio latency compensation
		song_position += GameManager.get_timing_offset()
		song_position_in_beats = int((song_position / seconds_per_beat) * 2) - 8
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
	last_reported_beat = -beats_before_start
	start_timer = Timer.new()
	start_timer.wait_time = seconds_per_beat / 2.0  # Half-beat intervals
	start_timer.timeout.connect(_emit_fake_beat)
	add_child(start_timer)
	start_timer.start()

func _emit_fake_beat() -> void:
	last_reported_beat += 1  # Increment by 1 for each half-beat
	emit_signal("beat", last_reported_beat)
	if last_reported_beat < -8:
		start_timer.start()
	else:
		start_timer.queue_free()
		play()
		
		
