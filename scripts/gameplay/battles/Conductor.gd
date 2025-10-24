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
var beats_before_start: int = 16
var current_measure: int = 1

var start_timer: Timer

func _ready() -> void:
	seconds_per_beat = 60.0 / bpm
	if OS.has_feature("web"):
		Engine.time_scale = 1.0
		# Increase audio buffer size for web
		AudioServer.set_bus_effect_enabled(0, 0, true)

func _physics_process(_delta: float) -> void:
	if playing:
		song_position = get_playback_position() + AudioServer.get_time_since_last_mix()
		song_position -= AudioServer.get_output_latency()

		# Web-specific latency compensation
		if OS.has_feature("web"):
			song_position += 0.05  # 50ms typical browser audio buffer delay

		# Fixed: removed *2 multiplier that was causing beat drift
		song_position_in_beats = int(song_position / seconds_per_beat) + beats_before_start
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
	start_timer.wait_time = seconds_per_beat
	start_timer.timeout.connect(_emit_fake_beat)
	add_child(start_timer)
	start_timer.start()

func _emit_fake_beat() -> void:
	last_reported_beat += 1
	emit_signal("beat", last_reported_beat)
	if last_reported_beat < 0:
		start_timer.start()
	else:
		start_timer.queue_free()
		play()
		
		
