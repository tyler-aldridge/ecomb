extends Control

## ============================================================================
## RHYTHM CALIBRATION (UNIVERSAL)
## ============================================================================
## Universal timing calibration scene accessible from anywhere:
## 1. Pre-game tutorial flow (auto-advances to PreGameCutscene2)
## 2. Options menu from title screen (returns to title)
## 3. Future: Overworld options menu (returns to overworld)
##
## Features:
## - 60 BPM (simple and slow)
## - Random quarter notes dropping
## - Metronome tone on beat 1 (440Hz sine wave)
## - Live timing adjustment slider (-1000 to +1000ms)
## - "Done Calibrating" button
## - Real-time feedback with explosions
##
## Usage:
## Set next_scene_path before instantiating to control where to go after calibration.
## ============================================================================

@export var next_scene_path: String = "res://scenes/cutscenes/PreGameCutscene2.tscn"

# Scene elements
var background: TextureRect
var conductor: Conductor
var hit_zones: Array = []
var active_notes: Array = []

# UI elements
var ui_container: VBoxContainer
var calibration_slider: HSlider
var slider_label: Label
var instructions_label: Label
var done_button: Button
var fade_overlay: ColorRect

# Audio
var hover_sound: AudioStreamPlayer
var click_sound: AudioStreamPlayer
var metronome_player: AudioStreamPlayer
var metronome_generator: AudioStreamGenerator
var metronome_playback: AudioStreamGeneratorPlayback

# Calibration state
const HITZONE_Y = 190.0  # 350px above screen center (540) - moved up 200px
const DESPAWN_Y = 490.0  # 100px below hit zones (190 + 200 + 100)
var bpm: float = 60.0
var last_spawn_bar: int = -1  # Track last bar we spawned on (spawn every 4 beats)
var last_metronome_beat: int = -1  # Track last beat for metronome
var conductor_started: bool = false  # Track if conductor has started (after fade)

# Effects
var effects_layer: Node2D

func _ready():
	setup_audio()
	setup_ui()
	fade_from_black()
	# Conductor will start after fade completes

func setup_audio():
	"""Setup audio players and sine wave generator for metronome."""
	# Hover sound
	hover_sound = AudioStreamPlayer.new()
	hover_sound.stream = preload("res://assets/audio/sfx/blip.ogg")
	hover_sound.bus = "SFX"
	add_child(hover_sound)

	# Click sound
	click_sound = AudioStreamPlayer.new()
	click_sound.stream = preload("res://assets/audio/sfx/blop.ogg")
	click_sound.bus = "SFX"
	add_child(click_sound)

	# Metronome sine wave generator (440Hz A note)
	metronome_generator = AudioStreamGenerator.new()
	metronome_generator.mix_rate = 44100
	metronome_generator.buffer_length = 0.1

	metronome_player = AudioStreamPlayer.new()
	metronome_player.stream = metronome_generator
	metronome_player.bus = "SFX"
	add_child(metronome_player)
	metronome_player.play()
	metronome_playback = metronome_player.get_stream_playback()

func play_metronome_beep():
	"""Generate and play a 440Hz sine wave beep."""
	if not metronome_playback:
		return

	var hz = 440.0
	var duration = 0.1  # 100ms beep
	var sample_rate = metronome_generator.mix_rate
	var pulse_hz = hz / sample_rate
	var samples_to_fill = int(duration * sample_rate)

	var frames_available = metronome_playback.get_frames_available()
	if frames_available < samples_to_fill:
		return

	for i in range(samples_to_fill):
		var sample = sin(i * pulse_hz * TAU)
		# Fade out at the end
		if i > samples_to_fill * 0.7:
			var fade = 1.0 - (float(i - samples_to_fill * 0.7) / (samples_to_fill * 0.3))
			sample *= fade
		metronome_playback.push_frame(Vector2(sample, sample))

func setup_ui():
	"""Create calibration UI with proper layout."""
	# Gradient background
	background = TextureRect.new()
	background.texture = preload("res://assets/interface/ui/panel-gradient-2.png")
	background.size = get_viewport().get_visible_rect().size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)

	# Create hit zones
	hit_zones = create_hit_zones()
	for zone in hit_zones:
		add_child(zone)

	# Create effects layer
	effects_layer = Node2D.new()
	effects_layer.z_index = 100
	add_child(effects_layer)

	# UI Container (centered below hit zones)
	ui_container = VBoxContainer.new()
	ui_container.position = Vector2(960 - 300, 650)  # Centered at screen X, below hit zones
	ui_container.custom_minimum_size = Vector2(600, 0)
	ui_container.add_theme_constant_override("separation", 30)
	add_child(ui_container)

	# Slider label (50px font, centered, max width 1500px)
	slider_label = Label.new()
	slider_label.text = "Timing Offset: 0ms"
	slider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slider_label.add_theme_font_size_override("font_size", 50)
	slider_label.add_theme_color_override("font_color", Color.WHITE)
	slider_label.custom_minimum_size = Vector2(1500, 0)
	ui_container.add_child(slider_label)

	# Calibration slider (-1000 to +1000ms, default 0)
	var slider_container = HBoxContainer.new()
	slider_container.custom_minimum_size = Vector2(600, 50)
	ui_container.add_child(slider_container)

	calibration_slider = HSlider.new()
	calibration_slider.min_value = -1000.0
	calibration_slider.max_value = 1000.0
	calibration_slider.step = 1.0
	calibration_slider.value = GameManager.get_setting("rhythm_timing_offset", 0)
	calibration_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calibration_slider.focus_mode = Control.FOCUS_CLICK  # Allow clicking
	calibration_slider.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse interaction
	calibration_slider.value_changed.connect(_on_slider_changed)

	# Style slider like options menu (white slider with black border)
	var slider_style = StyleBoxFlat.new()
	slider_style.bg_color = Color.WHITE
	slider_style.border_width_left = 2
	slider_style.border_width_top = 2
	slider_style.border_width_right = 2
	slider_style.border_width_bottom = 2
	slider_style.border_color = Color.BLACK
	slider_style.expand_margin_top = 10.0
	slider_style.expand_margin_bottom = 10.0
	calibration_slider.add_theme_stylebox_override("slider", slider_style)

	# Add grabber icon (use same as options menu)
	var grabber_texture = preload("res://assets/interface/ui/grabber.png")
	calibration_slider.add_theme_icon_override("grabber", grabber_texture)
	calibration_slider.add_theme_icon_override("grabber_highlight", grabber_texture)

	slider_container.add_child(calibration_slider)

	# Instructions label (50px font, centered, period added)
	instructions_label = Label.new()
	instructions_label.text = "Adjust timing until notes feel perfectly synchronized."
	instructions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions_label.add_theme_font_size_override("font_size", 50)
	instructions_label.add_theme_color_override("font_color", Color.WHITE)
	instructions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instructions_label.custom_minimum_size = Vector2(600, 0)
	ui_container.add_child(instructions_label)

	# Done button (centered, yellow border on hover, 50px font)
	done_button = Button.new()
	done_button.text = "Done Calibrating"
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done_button.custom_minimum_size = Vector2(400, 80)
	done_button.add_theme_font_size_override("font_size", 50)

	# Style button with yellow border on hover
	var button_hover_style = StyleBoxFlat.new()
	button_hover_style.bg_color = Color(0.8, 0.8, 0.8, 0.3)
	button_hover_style.border_width_left = 3
	button_hover_style.border_width_top = 3
	button_hover_style.border_width_right = 3
	button_hover_style.border_width_bottom = 3
	button_hover_style.border_color = Color.YELLOW
	done_button.add_theme_stylebox_override("hover", button_hover_style)

	var button_pressed_style = StyleBoxFlat.new()
	button_pressed_style.bg_color = Color(0.6, 0.6, 0.6, 0.3)
	button_pressed_style.border_width_left = 3
	button_pressed_style.border_width_top = 3
	button_pressed_style.border_width_right = 3
	button_pressed_style.border_width_bottom = 3
	button_pressed_style.border_color = Color.YELLOW
	done_button.add_theme_stylebox_override("pressed", button_pressed_style)

	done_button.pressed.connect(_on_done_pressed)
	done_button.mouse_entered.connect(_on_button_hover)
	ui_container.add_child(done_button)

	# Update slider label with initial value
	_on_slider_changed(calibration_slider.value)

	# Fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.z_index = 200
	add_child(fade_overlay)

func create_hit_zones() -> Array:
	"""Create hit zones for calibration at 150px above screen center."""
	var zones = []
	var lane_positions = [
		Vector2(610.0, HITZONE_Y),
		Vector2(860.0, HITZONE_Y),
		Vector2(1110.0, HITZONE_Y)
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
	"""Create and configure conductor for 60 BPM with silent audio for timing."""
	conductor = Conductor.new()
	conductor.bpm = bpm
	conductor.sec_per_beat = 60.0 / bpm
	conductor.subdivision = 2
	add_child(conductor)

	# Create a silent audio stream for the Conductor to track timing
	# This ensures the Conductor applies the rhythm_timing_offset correctly
	# Duration: 60 seconds at 60 BPM = 60 beats, plenty for calibration
	var silent_stream = AudioStreamGenerator.new()
	silent_stream.mix_rate = 44100
	silent_stream.buffer_length = 60.0  # 60 seconds of silent audio

	# Give the silent stream to the Conductor's music player
	await get_tree().process_frame  # Wait for Conductor to be ready
	if conductor.music_player:
		conductor.music_player.stream = silent_stream

	# Start conductor playback (will play silent audio)
	conductor.play_with_beat_offset()

func fade_from_black():
	"""Fade in from black, then start conductor."""
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, 3.0).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_start_conductor)

func _start_conductor():
	"""Start conductor after fade completes."""
	setup_conductor()
	conductor_started = true

func _process(delta):
	"""Spawn notes based on Conductor beats and play metronome when notes are centered."""
	if not conductor or not conductor_started:
		return

	# Spawn notes on beat 1 of every bar (every 4 beats)
	# This uses the Conductor's timing which includes the offset
	var current_bar = int(conductor.song_pos_in_beats / 4.0)
	if current_bar > last_spawn_bar and conductor.song_pos_in_beats >= 0:
		# New bar started - spawn a note on beat 1
		spawn_random_note()
		last_spawn_bar = current_bar

	# Play metronome when notes reach center of hit zone
	# Notes spawn at FALL_BEATS ahead, so metronome plays at that beat
	# When conductor.song_pos_in_beats reaches note_beat, note is centered
	var current_beat = int(conductor.song_pos_in_beats) % 4
	if current_beat == 0 and last_metronome_beat != 0 and conductor.song_pos_in_beats >= BattleManager.FALL_BEATS:
		# Beat aligned with note center - play metronome sine wave
		play_metronome_beep()
	last_metronome_beat = current_beat

	# Clean up despawned notes (100px below hit zones)
	var i = 0
	while i < active_notes.size():
		var note = active_notes[i]
		if not is_instance_valid(note):
			active_notes.remove_at(i)
			continue

		# Despawn if 100px below bottom of hit zones
		if note.position.y > DESPAWN_Y:
			active_notes.remove_at(i)
			note.queue_free()
		else:
			i += 1

func spawn_random_note():
	"""Spawn a note in a random lane."""
	if not conductor:
		return

	var lane = str(randi() % 3 + 1)  # "1", "2", or "3"
	var note_beat = conductor.song_pos_in_beats + BattleManager.FALL_BEATS

	# Load quarter note scene
	var note_scene = BattleManager.NOTE_TYPE_CONFIG["quarter"]["scene"]
	var note = note_scene.instantiate()
	note.z_index = 50
	add_child(note)

	# Setup note with new hit zone Y position
	var spawn_y = BattleManager.calculate_note_spawn_y(200.0)
	var target_y = BattleManager.calculate_note_target_y(HITZONE_Y, 200.0)

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
	var closest_note = null
	var best_distance = 999999.0

	for note in active_notes:
		if not is_instance_valid(note):
			continue

		if note.track_key == track_key:
			var note_height = 200.0
			var note_center_y = note.position.y + (note_height / 2.0)
			var hit_zone_center_y = HITZONE_Y + (BattleManager.HITZONE_HEIGHT / 2.0)
			var distance = abs(note_center_y - hit_zone_center_y)

			if distance < best_distance:
				best_distance = distance
				closest_note = note

	if closest_note:
		# Get hit quality
		var hit_quality = BattleManager.get_hit_quality_for_note(closest_note, HITZONE_Y)

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
	if slider_label:
		slider_label.text = "Timing Offset: " + str(int(value)) + "ms"

func _on_button_hover():
	"""Play hover sound when mouse enters button."""
	if hover_sound:
		hover_sound.play()

func _on_done_pressed():
	"""Handle Done button press."""
	# Play click sound
	if click_sound:
		click_sound.play()

	# Fade to black and transition to next scene
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, 3.0).set_ease(Tween.EASE_IN)
	tween.tween_callback(_load_next_scene)

func _load_next_scene():
	"""Load the next scene in the flow."""
	if next_scene_path != "":
		# Mark tutorial calibration as complete
		GameManager.set_setting("has_calibrated", true)
		Router.goto_scene_with_fade(next_scene_path, 3.0)
	else:
		push_error("TutorialCalibrationScene: next_scene_path not set!")
