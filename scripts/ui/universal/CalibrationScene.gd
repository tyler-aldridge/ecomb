extends Control

## ============================================================================
## CALIBRATION SCENE (UNIVERSAL)
## ============================================================================
## Universal timing calibration scene accessible from:
## 1. Pre-game tutorial flow (auto-advances to PreGameCutscene2)
## 2. Overworld options menu (returns to options menu)
##
## Features:
## - 60 BPM (simple and slow)
## - Random quarter notes dropping
## - Metronome tone on beat 1
## - Live timing adjustment slider
## - "Done Calibrating" button (no forced perfect hits)
## - Real-time feedback with explosions
##
## Usage:
## Set next_scene_path before instantiating to control where to go after calibration.
## ============================================================================

@export var next_scene_path: String = "res://scenes/ui/cutscenes/PreGameCutscene2.tscn"

# Scene elements
var background: ColorRect
var conductor: Conductor
var hit_zones: Array = []
var active_notes: Array = []

# UI elements
var calibration_slider: HSlider
var instructions_label: Label
var done_button: Button
var fade_overlay: ColorRect

# Calibration state
var bpm: float = 60.0
var spawn_timer: float = 0.0
var spawn_interval: float = 1.0  # Spawn every beat at 60 BPM

# Effects
var effects_layer: Node2D

func _ready():
	setup_ui()
	setup_conductor()
	fade_from_black()

func setup_ui():
	"""Create calibration UI."""
	# Black background
	background = ColorRect.new()
	background.color = Color.BLACK
	background.size = get_viewport().get_visible_rect().size
	add_child(background)

	# Create hit zones
	hit_zones = create_hit_zones()
	for zone in hit_zones:
		add_child(zone)

	# Create effects layer
	effects_layer = Node2D.new()
	effects_layer.z_index = 100
	add_child(effects_layer)

	# Calibration slider (100px below hit zones)
	calibration_slider = HSlider.new()
	calibration_slider.position = Vector2(660, 900)
	calibration_slider.size = Vector2(600, 40)
	calibration_slider.min_value = -200.0
	calibration_slider.max_value = 200.0
	calibration_slider.step = 1.0
	calibration_slider.value = GameManager.get_setting("rhythm_timing_offset", 0)
	calibration_slider.value_changed.connect(_on_slider_changed)
	add_child(calibration_slider)

	# Slider label
	var slider_label = Label.new()
	slider_label.text = "Timing Offset: " + str(int(calibration_slider.value)) + "ms"
	slider_label.position = Vector2(860, 870)
	slider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slider_label.add_theme_font_size_override("font_size", 20)
	slider_label.add_theme_color_override("font_color", Color.WHITE)
	calibration_slider.set_meta("label", slider_label)
	add_child(slider_label)

	# Instructions label (50px below slider)
	instructions_label = Label.new()
	instructions_label.text = "Adjust timing until notes feel perfectly synchronized"
	instructions_label.position = Vector2(960, 950)
	instructions_label.size = Vector2(800, 50)
	instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions_label.add_theme_font_size_override("font_size", 24)
	instructions_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(instructions_label)

	# Done button (50px below label)
	done_button = Button.new()
	done_button.text = "Done Calibrating"
	done_button.position = Vector2(810, 1010)
	done_button.size = Vector2(300, 60)
	done_button.add_theme_font_size_override("font_size", 24)
	done_button.pressed.connect(_on_done_pressed)
	add_child(done_button)

	# Fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.z_index = 200
	add_child(fade_overlay)

func create_hit_zones() -> Array:
	"""Create hit zones for calibration."""
	var zones = []
	var lane_positions = [
		Vector2(610.0, 650.0),
		Vector2(860.0, 650.0),
		Vector2(1110.0, 650.0)
	]

	for i in range(3):
		var zone = ColorRect.new()
		zone.color = Color(1, 1, 1, 0.1)
		zone.size = Vector2(200, 200)
		zone.position = lane_positions[i]

		# Add white border
		var border = Line2D.new()
		border.width = 3.0
		border.default_color = Color.WHITE
		border.add_point(Vector2(0, 0))
		border.add_point(Vector2(200, 0))
		border.add_point(Vector2(200, 200))
		border.add_point(Vector2(0, 200))
		border.add_point(Vector2(0, 0))
		zone.add_child(border)

		zones.append(zone)

	return zones

func setup_conductor():
	"""Create and configure conductor for 60 BPM."""
	conductor = Conductor.new()
	conductor.bpm = bpm
	conductor.sec_per_beat = 60.0 / bpm
	conductor.subdivision = 2
	add_child(conductor)

	# TODO: Load metronome audio
	# For now, just start silent playback
	conductor.play_with_beat_offset()

func fade_from_black():
	"""Fade in from black."""
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 3.0).set_ease(Tween.EASE_OUT)

func _process(delta):
	"""Spawn notes periodically."""
	spawn_timer += delta

	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_random_note()

	# Clean up off-screen notes
	var i = 0
	while i < active_notes.size():
		var note = active_notes[i]
		if note.is_past_despawn_threshold():
			active_notes.remove_at(i)
			note.queue_free()
		else:
			i += 1

func spawn_random_note():
	"""Spawn a note in a random lane."""
	var lane = str(randi() % 3 + 1)  # "1", "2", or "3"
	var note_beat = conductor.song_pos_in_beats + BattleManager.FALL_BEATS

	# Load quarter note scene
	var note_scene = BattleManager.NOTE_TYPE_CONFIG["quarter"]["scene"]
	var note = note_scene.instantiate()
	note.z_index = 50
	add_child(note)

	# Setup note
	var hitzone_y = 650.0
	var spawn_y = BattleManager.calculate_note_spawn_y(200.0)
	var target_y = BattleManager.calculate_note_target_y(hitzone_y, 200.0)

	note.setup_interpolation(lane, note_beat, "quarter", conductor, spawn_y, target_y, BattleManager.FALL_BEATS)
	active_notes.append(note)

func _input(event):
	"""Handle player input for hitting notes."""
	if event is InputEventKey and event.pressed:
		var lane_key = ""
		match event.keycode:
			KEY_1:
				lane_key = "1"
			KEY_2:
				lane_key = "2"
			KEY_3:
				lane_key = "3"

		if lane_key != "":
			check_hit(lane_key)

func check_hit(track_key: String):
	"""Check for note hits and show feedback."""
	var hit_zone_y = 650.0
	var closest_note = null
	var best_distance = 999999.0

	for note in active_notes:
		if note.track_key == track_key:
			var note_height = 200.0
			var note_center_y = note.position.y + (note_height / 2.0)
			var hit_zone_center_y = hit_zone_y + (BattleManager.HITZONE_HEIGHT / 2.0)
			var distance = abs(note_center_y - hit_zone_center_y)

			if distance < best_distance:
				best_distance = distance
				closest_note = note

	if closest_note:
		# Get hit quality
		var hit_quality = BattleManager.get_hit_quality_for_note(closest_note, hit_zone_y)

		# Show feedback
		var effect_pos = closest_note.position + Vector2(100, 100)

		if hit_quality == "MISS":
			BattleManager.explode_note_at_position(closest_note, "black", 2, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position("MISS", effect_pos, true, effects_layer, self)
		else:
			var feedback_text = BattleManager.get_random_feedback_text(hit_quality)
			BattleManager.explode_note_at_position(closest_note, BattleManager.get_track_color(track_key), 3, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)

		# Remove note
		BattleManager.create_fade_out_tween(closest_note, bpm)
		active_notes.erase(closest_note)

func _on_slider_changed(value: float):
	"""Handle calibration slider change."""
	GameManager.set_setting("rhythm_timing_offset", int(value))

	# Update label
	var label = calibration_slider.get_meta("label") as Label
	if label:
		label.text = "Timing Offset: " + str(int(value)) + "ms"

func _on_done_pressed():
	"""Handle Done button press."""
	# Fade to black and transition to next scene
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 3.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(_load_next_scene)

func _load_next_scene():
	"""Load the next scene in the flow."""
	if next_scene_path != "":
		# Mark tutorial calibration as complete
		GameManager.set_setting("has_calibrated", true)
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_error("TutorialCalibrationScene: next_scene_path not set!")
