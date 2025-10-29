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

# Time signature subdivision: 2 for simple meters (4/4, 3/4, 7/4), 3 for compound meters (6/8, 9/8, 12/8)
# Controls how Conductor converts beats to ticks (eighth notes vs triplets)
var subdivision: int = 2

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
	# Suspend all processing while paused
	if stream_paused:
		return

	if playing:
		# Refresh latency cache every second (not every frame)
		latency_cache_timer += delta
		if latency_cache_timer >= 1.0:
			cached_output_latency = AudioServer.get_output_latency()
			# Web browsers often report incorrect latency, disable if unrealistic
			if OS.has_feature("web") and cached_output_latency < 0.05:
				cached_output_latency = 0.0
			latency_cache_timer = 0.0

		# Get audio playback position
		# NOTE: On web, browser audio buffering causes get_playback_position() to report
		# the stream decode position, which is ~0.5-1.0s BEHIND actual speaker output
		var playback_pos = get_playback_position()
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
	last_reported_beat = -beats_before_start
	start_timer = Timer.new()
	# Subdivision determines tick rate: 2 for simple (half-beat), 3 for compound (triplet)
	start_timer.wait_time = seconds_per_beat / float(subdivision)
	start_timer.timeout.connect(_emit_fake_beat)
	add_child(start_timer)
	start_timer.start()

func _emit_fake_beat() -> void:
	last_reported_beat += 1  # Increment by 1 for each tick
	emit_signal("beat", last_reported_beat)
	# Stop countdown at 4 beats before music starts (4 * subdivision ticks)
	if last_reported_beat < -(4 * subdivision):
		start_timer.start()
	else:
		start_timer.queue_free()
		play()
		
		
