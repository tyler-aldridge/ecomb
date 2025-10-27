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

var start_timer: Timer

func _ready() -> void:
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
	if playing:
		# Refresh latency cache every second (not every frame)
		latency_cache_timer += delta
		if latency_cache_timer >= 1.0:
			cached_output_latency = AudioServer.get_output_latency()
			# Web browsers often report incorrect latency, disable if unrealistic
			if OS.has_feature("web") and cached_output_latency < 0.05:
				cached_output_latency = 0.0
			latency_cache_timer = 0.0

		song_position = get_playback_position() + AudioServer.get_time_since_last_mix()
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
		
		
