extends Node2D

@onready var conductor = $Conductor
@onready var hit_zones = $HitZones
@onready var player_sprite = $TutorialUI/Player
@onready var trainer_sprite = $TutorialUI/Trainer

# Level data
@export var level_data_path: String = "res://data/levels/battle/BattleTutorial.json"
var level_data: Dictionary = {}

# Note type configuration (scalable for future note types)
# To add a new note type:
#   1. Create scene file with appropriate size (e.g., HalfNote.tscn at 200x400)
#   2. Add entry here with scene path, travel_time, and spawn_offset
#   3. Add note type to level JSON files
#   4. All hit detection, spawn positioning, and timing automatically scale!
const NOTE_TYPE_CONFIG = {
	"whole": {
		"scene": preload("res://scenes/ui/battle/LongNote.tscn"),  # 200x800
		"travel_time": 3.0,
		"spawn_offset": 17  # 3.0s at 152 BPM = 15.2, but empirically needs 17
	},
	"half": {
		"scene": preload("res://scenes/ui/battle/Note.tscn"),  # Will use 200x400 scene when created
		"travel_time": 1.55,
		"spawn_offset": 8
	},
	"quarter": {
		"scene": preload("res://scenes/ui/battle/Note.tscn"),  # 200x200
		"travel_time": 1.55,
		"spawn_offset": 8  # 1.55s at 152 BPM = 7.85 ≈ 8 half-beats
	}
}

var hit_zone_positions = {
	"1": Vector2(660.0, 650.0),
	"2": Vector2(860.0, 650.0),
	"3": Vector2(1060.0, 650.0)
}

# Spawn settings
const SPAWN_HEIGHT_ABOVE_TARGET = 1000.0

# Timing windows
const PERFECT_WINDOW_BASE = 20.0  # ±20px for quarter notes
const GOOD_WINDOW = 300.0         # ±300px - generous for all notes
const OKAY_WINDOW = 500.0         # ±500px - any overlap
const MISS_WINDOW = 150.0         # Auto-miss threshold for notes that passed

# Hit detection
var active_notes = []

# Track recent note spawns to prevent overlapping
var recent_note_spawns = {}  # {beat_position: lane}
const OVERLAP_PREVENTION_WINDOW = 6  # Half-beats window to prevent same-lane spawns

# Scoring
var score = 0
var combo = 0
var max_combo = 0

# Effects layer
var effects_layer: Node2D

# Character positions
var player_original_pos: Vector2
var trainer_original_pos: Vector2

# Fade overlay
var fade_overlay: ColorRect

# Hit zone indicators
var hit_zone_indicator_nodes = []

# Battle UI elements
var groove_bar: Control
var combo_display: Label
var xp_gain_display: Label
var battle_results: Control
var battle_failure: Control

# ============================================================================
# UNIVERSAL BAR/BEAT SYSTEM
# ============================================================================

func clamp_to_screen(element_pos: Vector2, element_size: Vector2, margin: float = 50.0) -> Vector2:
	"""Clamp a position to keep an element visible on screen.

	Args:
		element_pos: Top-left position of the element
		element_size: Size of the element (width, height)
		margin: Minimum margin from screen edge in pixels

	Returns:
		Clamped position that keeps the element visible
	"""
	var viewport_size = get_viewport().get_visible_rect().size

	var clamped_x = clamp(element_pos.x, margin, viewport_size.x - element_size.x - margin)
	var clamped_y = clamp(element_pos.y, margin, viewport_size.y - element_size.y - margin)

	return Vector2(clamped_x, clamped_y)

func bar_beat_to_position(bar: int, beat: Variant) -> int:
	"""Convert Bar/Beat notation to beat_position (HIT time).

	Formula: beat_position = (bar - 1) * 8 + (beat - 1) * 2 - 8

	Args:
		bar: Bar number (e.g., 91)
		beat: Beat number or string with 'a' for AND (e.g., 3, "1a", 2.5)
			  Numeric beats: 1, 2, 3, 4
			  AND beats: "1a", "2a", "3a", "4a" (or 1.5, 2.5, 3.5, 4.5)

	Returns:
		beat_position as integer

	Examples:
		bar_beat_to_position(91, 3) → 716 (Bar 91 Beat 3)
		bar_beat_to_position(92, "1a") → 721 (Bar 92 Beat 1 AND)
		bar_beat_to_position(92, 1.5) → 721 (same as above)
	"""
	var beat_num: float

	# Parse beat notation
	if typeof(beat) == TYPE_STRING:
		if beat.ends_with("a"):
			# AND note: "1a", "2a", etc.
			var base_beat = int(beat.substr(0, beat.length() - 1))
			beat_num = float(base_beat) + 0.5
		else:
			beat_num = float(beat)
	else:
		beat_num = float(beat)

	# Calculate beat position
	var base_pos = (bar - 1) * 8 + (int(beat_num) - 1) * 2 - 8

	# Add 1 for AND notes (half-beat offset)
	if beat_num != int(beat_num):  # Has decimal (e.g., 1.5)
		base_pos += 1

	return base_pos

func _ready():
	# Load level data
	load_level_data()

	# Configure conductor from level data
	if level_data.has("bpm"):
		conductor.bpm = float(level_data["bpm"])
		conductor.seconds_per_beat = 60.0 / conductor.bpm
	if level_data.has("beats_before_start"):
		conductor.beats_before_start = int(level_data["beats_before_start"])
	if level_data.has("audio_file"):
		var audio_path = level_data["audio_file"]
		var audio_stream = load(audio_path)
		if audio_stream:
			conductor.stream = audio_stream
		else:
			push_error("Failed to load audio file: " + audio_path)

	# Start battle with BattleManager
	var battle_data = {
		"battle_id": level_data.get("battle_id", ""),
		"battle_level": level_data.get("battle_level", 1),
		"battle_type": level_data.get("battle_type", "story"),
		"groove_start": level_data.get("groove_start", 50.0),
		"groove_miss_penalty": level_data.get("groove_miss_penalty", 10.0)
	}
	BattleManager.start_battle(battle_data)

	# Connect to battle failure signal
	if not BattleManager.battle_failed.is_connected(_on_battle_failed):
		BattleManager.battle_failed.connect(_on_battle_failed)

	# Create fade overlay
	create_fade_overlay()
	fade_from_black()

	# Create effects layer
	effects_layer = Node2D.new()
	effects_layer.z_index = 100
	add_child(effects_layer)

	# Create battle UI elements
	create_battle_ui()

	setup_hit_zone_borders()
	start_character_animations()
	conductor.beat.connect(_on_beat)

	# Start with beat offset
	await get_tree().create_timer(1.0).timeout
	conductor.play_with_beat_offset()

func _exit_tree():
	"""Clean up tweens to prevent lambda capture errors when scene is freed."""
	# Kill all tweens on this node to prevent lambda callbacks from accessing freed objects
	var tween_count = get_tree().get_processed_tweens()
	for tween in tween_count:
		if is_instance_valid(tween):
			tween.kill()

func create_battle_ui():
	"""Instantiate and add battle UI elements to a CanvasLayer."""
	# Create UI layer for proper screen-space rendering
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	# Groove bar (full width at top)
	var groove_bar_scene = preload("res://scenes/ui/battle/GrooveBar.tscn")
	groove_bar = groove_bar_scene.instantiate()
	ui_layer.add_child(groove_bar)

	# Combo display (center of screen, 313px from center)
	var combo_display_scene = preload("res://scenes/ui/battle/ComboDisplay.tscn")
	combo_display = combo_display_scene.instantiate()
	ui_layer.add_child(combo_display)

	# XP gain display (above combo display)
	var xp_gain_display_scene = preload("res://scenes/ui/battle/XPGainDisplay.tscn")
	xp_gain_display = xp_gain_display_scene.instantiate()
	ui_layer.add_child(xp_gain_display)

	# Battle results menu (hidden until battle completes successfully)
	var battle_results_scene = preload("res://scenes/ui/battle/BattleResults.tscn")
	battle_results = battle_results_scene.instantiate()
	ui_layer.add_child(battle_results)

	# Battle failure dialog (hidden until battle fails)
	var battle_failure_scene = preload("res://scenes/ui/battle/BattleFailure.tscn")
	battle_failure = battle_failure_scene.instantiate()
	ui_layer.add_child(battle_failure)

func load_level_data():
	var file = FileAccess.open(level_data_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			level_data = json.data

			# Convert Bar/Beat notation to beat_position and calculate spawn times
			convert_bar_beat_to_spawn_positions()
		else:
			push_error("Failed to parse level data JSON: " + json.get_error_message())
	else:
		push_error("Failed to load level data from: " + level_data_path)

func convert_bar_beat_to_spawn_positions():
	"""Converts Bar/Beat notation to beat_position and calculates spawn times.
	JSON can include:
	  - bar/beat: Auto-calculates beat_position using formula
	  - beat_position: Use this value directly (allows manual override)
	Then subtracts spawn_offset to get spawn time."""

	# Convert all notes from Bar/Beat to spawn_position
	if level_data.has("notes"):
		for note_data in level_data["notes"]:
			var note_type = note_data.get("note", "quarter")
			var hit_position: int

			# Check if beat_position is provided in JSON
			if note_data.has("beat_position"):
				# Use the provided beat_position (allows manual override)
				hit_position = int(note_data["beat_position"])
			else:
				# Calculate from bar/beat notation
				var bar = int(note_data.get("bar", 1))
				var beat = note_data.get("beat", 1)
				hit_position = bar_beat_to_position(bar, beat)

			# Calculate spawn time by subtracting travel offset
			var spawn_offset = NOTE_TYPE_CONFIG[note_type]["spawn_offset"] if NOTE_TYPE_CONFIG.has(note_type) else 8
			var spawn_position = hit_position - spawn_offset

			# Store spawn position for use in _on_beat
			note_data["spawn_position"] = spawn_position

func create_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.z_index = 1000
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func fade_from_black():
	if not is_instance_valid(fade_overlay):
		return
	fade_overlay.modulate.a = 1.0
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, 1.5)

func setup_hit_zone_borders():
	for i in range(3):
		var hit_zone = hit_zones.get_child(i)
		hit_zone.color = Color(1, 1, 1, 0)
		
		var border = Line2D.new()
		border.width = 3.0
		border.default_color = Color.WHITE
		border.add_point(Vector2(0, 0))
		border.add_point(Vector2(200, 0))
		border.add_point(Vector2(200, 200))
		border.add_point(Vector2(0, 200))
		border.add_point(Vector2(0, 0))
		hit_zone.add_child(border)

func start_character_animations():
	if player_sprite:
		player_original_pos = player_sprite.position
		if player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("idle"):
			player_sprite.play("idle")
	
	if trainer_sprite:
		trainer_original_pos = trainer_sprite.position
		if trainer_sprite.sprite_frames and trainer_sprite.sprite_frames.has_animation("idle"):
			trainer_sprite.play("idle")

func _on_beat(beat_position: int):
	check_automatic_misses()

	# Process dialogue events
	if level_data.has("dialogue"):
		for dialogue in level_data["dialogue"]:
			if int(dialogue.get("beat_position", 0)) == beat_position:
				var text = dialogue.get("text", "")
				var character = dialogue.get("character", "trainer")
				var duration = dialogue.get("duration", 3.0)
				DialogManager.show_dialog(text, character, duration)

				# Handle triggers
				if dialogue.has("triggers"):
					handle_trigger(dialogue["triggers"])

	# Process countdown events
	if level_data.has("countdowns"):
		for countdown in level_data["countdowns"]:
			if int(countdown.get("beat_position", 0)) == beat_position:
				var text = countdown.get("text", "")
				var countdown_type = countdown.get("type", "single")
				if countdown_type == "multi":
					var values = countdown.get("values", [])
					var interval = countdown.get("interval", 0.5)
					var size = int(countdown.get("size", 500))
					DialogManager.show_countdown(values, interval, size)
				elif countdown_type == "single":
					var duration = countdown.get("duration", 1.0)
					var size = int(countdown.get("size", 500))
					var color_str = countdown.get("color", "white")
					var color = Color.WHITE
					if color_str == "red":
						color = Color.RED
					DialogManager.show_countdown_number(text, duration, size, color)

	# Process trigger events
	if level_data.has("triggers"):
		for trigger in level_data["triggers"]:
			if int(trigger.get("beat_position", 0)) == beat_position:
				var trigger_name = trigger.get("trigger", "")
				handle_trigger(trigger_name)

	# Process notes - check if any note should spawn at this beat
	if level_data.has("notes"):
		for note_data in level_data["notes"]:
			if int(note_data.get("spawn_position", 0)) == beat_position:
				var note_type = note_data.get("note", "quarter")
				spawn_note_by_type(note_type)

func handle_trigger(trigger_name: String):
	match trigger_name:
		"create_hit_zone_indicators":
			create_hit_zone_indicators()
		"stop_hit_zone_indicators":
			stop_hit_zone_indicators()
		"fade_to_title":
			fade_to_title()

func delayed_fade_to_title():
	await get_tree().create_timer(5.0).timeout
	fade_to_title()

func spawn_note_by_type(note_type: String):
	"""Unified note spawning function that uses NOTE_TYPE_CONFIG for scalability"""
	if not NOTE_TYPE_CONFIG.has(note_type):
		push_warning("Unknown note type '" + note_type + "', defaulting to 'quarter'")
		note_type = "quarter"

	var config = NOTE_TYPE_CONFIG[note_type]
	var current_beat = conductor.song_position_in_beats if conductor else 0
	var random_track = choose_lane_avoiding_overlap(current_beat)
	var target_pos = hit_zone_positions[random_track]

	# Instantiate note from config
	var note = config["scene"].instantiate()
	add_child(note)

	# Get note's actual height dynamically for scalable spawn positioning
	var note_height = 200.0  # Default
	if note.has_node("NoteTemplate"):
		note_height = note.get_node("NoteTemplate").size.y

	# Calculate spawn position: spawn above screen + note's full height
	# So the note spawns completely off-screen regardless of size
	var extra_offset = note_height - 200.0  # Extra height beyond standard 200px note
	var spawn_pos = Vector2(target_pos.x, target_pos.y - SPAWN_HEIGHT_ABOVE_TARGET - extra_offset)

	note.z_index = 50
	note.setup(random_track, spawn_pos, target_pos.y)
	note.set_travel_time(config["travel_time"])
	note.set_meta("note_type", note_type)  # Use note_type instead of is_ambient
	active_notes.append(note)

func create_hit_zone_indicators():
	# Clear any existing indicators first
	stop_hit_zone_indicators()

	for i in range(3):
		var zone_key = str(i + 1)
		var pos = hit_zone_positions[zone_key]

		var border = Line2D.new()
		border.width = 5.0
		border.default_color = Color.YELLOW
		border.modulate.a = 0.0  # Start invisible for fade in
		border.add_point(Vector2(0, 0))
		border.add_point(Vector2(200, 0))
		border.add_point(Vector2(200, 200))
		border.add_point(Vector2(0, 200))
		border.add_point(Vector2(0, 0))
		border.position = pos
		border.z_index = 350
		add_child(border)
		hit_zone_indicator_nodes.append(border)

		# Fade in border
		var border_fade_tween = create_tween()
		border_fade_tween.tween_property(border, "modulate:a", 1.0, 0.5)

		var label = Label.new()
		label.text = zone_key
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 100)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.position = pos + Vector2(50, 50)
		label.size = Vector2(100, 100)
		label.pivot_offset = Vector2(50, 50)  # Scale from center
		label.modulate.a = 0.0  # Start invisible for fade in
		label.z_index = 350
		add_child(label)
		hit_zone_indicator_nodes.append(label)

		# Fade in label
		var fade_tween = create_tween()
		fade_tween.tween_property(label, "modulate:a", 1.0, 0.5)

		# Pulsing scale animation
		var scale_tween = create_tween()
		scale_tween.set_loops(200)  # Loop for a very long time (200 loops = ~130 seconds)
		scale_tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.325)
		scale_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.325)

func stop_hit_zone_indicators():
	"""Fade out and remove all hit zone indicator nodes (yellow borders and numbers)."""
	for indicator in hit_zone_indicator_nodes:
		if is_instance_valid(indicator):
			# Capture the indicator in a local variable to avoid loop variable issues
			var ind = indicator
			var fade_out_tween = create_tween()
			fade_out_tween.tween_property(ind, "modulate:a", 0.0, 0.5)
			fade_out_tween.tween_callback(func():
				if is_instance_valid(ind):
					ind.queue_free()
			)
	hit_zone_indicator_nodes.clear()

func fade_to_title():
	# Hide battle UI elements (combo display and groove bar) before showing results
	hide_battle_ui()

	# End battle and get results (only if battle is still active)
	var results = {}
	if BattleManager.is_battle_active():
		results = BattleManager.end_battle()

	var battle_succeeded = results.get("battle_completed", false)

	if battle_succeeded:
		# Battle completed successfully - award Strength (XP)
		var strength_awarded = results.get("strength_awarded", 0)
		GameManager.add_strength(strength_awarded)

		# Record story/lesson battle completion
		if results.get("battle_type", "") == "story" or results.get("battle_type", "") == "lesson":
			var battle_id = results.get("battle_id", "")
			var strength_total = results.get("strength_total", 0)
			GameManager.record_story_battle_completion(battle_id, strength_total)

		# Mark tutorial as completed
		if results.get("battle_id", "") == "battle_tutorial":
			GameManager.complete_tutorial()

	# Fade to black
	if not is_instance_valid(fade_overlay):
		if battle_succeeded and is_instance_valid(battle_results):
			battle_results.show_battle_results(results)
		else:
			change_to_title()
		return

	fade_overlay.modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 2.0)

	# Capture variables for lambda to avoid freed object errors
	var succeeded = battle_succeeded
	var results_copy = results.duplicate()
	var br = battle_results

	fade_tween.tween_callback(func():
		# After fade to black, show BattleResults if succeeded, otherwise go to title
		if succeeded and is_instance_valid(br):
			br.show_battle_results(results_copy)
		elif is_instance_valid(self):
			change_to_title()
	)

func _on_battle_failed():
	# Hide battle UI elements (combo display and groove bar)
	hide_battle_ui()

	"""Called when groove reaches 0% - battle failure."""
	# Stop the music
	if conductor:
		conductor.stop()

	# BattleFailure dialog automatically shows via BattleManager.battle_failed signal

func hide_battle_ui():
	"""Hide combo display and groove bar when battle ends."""
	if combo_display:
		combo_display.visible = false
	if groove_bar:
		groove_bar.visible = false

func change_to_title():
	if is_instance_valid(GameManager):
		GameManager.complete_tutorial()
	if is_instance_valid(get_tree()):
		get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func choose_lane_avoiding_overlap(current_beat: int) -> String:
	"""Choose a lane that avoids recent spawns to prevent visual overlap."""
	var tracks = ["1", "2", "3"]
	var available_tracks = tracks.duplicate()

	# Remove lanes that have recent spawns within the overlap window
	for beat_pos in recent_note_spawns.keys():
		if abs(current_beat - beat_pos) <= OVERLAP_PREVENTION_WINDOW:
			var used_lane = recent_note_spawns[beat_pos]
			available_tracks.erase(used_lane)

	# If all lanes are blocked, just use any lane
	if available_tracks.size() == 0:
		available_tracks = tracks.duplicate()

	# Choose random from available lanes
	var chosen_lane = available_tracks[randi() % available_tracks.size()]

	# Record this spawn
	recent_note_spawns[current_beat] = chosen_lane

	# Clean up old entries to prevent dict from growing indefinitely
	for beat_pos in recent_note_spawns.keys():
		if abs(current_beat - beat_pos) > OVERLAP_PREVENTION_WINDOW * 2:
			recent_note_spawns.erase(beat_pos)

	return chosen_lane

func check_automatic_misses():
	for note in active_notes:
		if is_instance_valid(note):
			var hit_zone_y = hit_zone_positions[note.track_key].y
			if note.position.y > hit_zone_y + MISS_WINDOW:
				# Get note's actual height dynamically
				var note_height = 200.0  # Default
				if note.has_node("NoteTemplate"):
					note_height = note.get_node("NoteTemplate").size.y

				# Calculate effect position at note's center (dynamic for any note size)
				var effect_pos = note.position + Vector2(100, note_height / 2.0)

				explode_note_at_position(note, "black", 2, effect_pos)
				show_feedback_at_position(get_random_feedback_text("MISS"), effect_pos, true)
				process_miss()
				fade_out_note(note)
				active_notes.erase(note)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			handle_input("1")
		elif event.keycode == KEY_2:
			handle_input("2")
		elif event.keycode == KEY_3:
			handle_input("3")

func handle_input(track_key: String):
	flash_hit_zone(track_key)
	check_hit(track_key)

func flash_hit_zone(track_key: String):
	var hit_zone_node = null
	match track_key:
		"1": hit_zone_node = $HitZones/HitZone1
		"2": hit_zone_node = $HitZones/HitZone2
		"3": hit_zone_node = $HitZones/HitZone3
	
	if hit_zone_node:
		hit_zone_node.modulate = Color.WHITE
		var flash_tween = create_tween()
		flash_tween.tween_property(hit_zone_node, "modulate", Color(1, 1, 1, 1), 0.1)

func check_hit(track_key: String):
	var hit_zone_y = hit_zone_positions[track_key].y
	var closest_note = null
	var best_distance = 999999.0

	# Clean up invalid notes first
	var valid_notes = []
	for note in active_notes:
		if is_instance_valid(note):
			valid_notes.append(note)
	active_notes = valid_notes

	for note in active_notes:
		if note.track_key == track_key:
			var distance = 999999.0

			# Get note's actual height dynamically for scalability
			var note_height = 200.0  # Default
			if note.has_node("NoteTemplate"):
				note_height = note.get_node("NoteTemplate").size.y

			# Calculate centers dynamically based on actual note size
			var note_center_y = note.position.y + (note_height / 2.0)
			var hit_zone_center_y = hit_zone_y + 100.0  # HitZone is always 200px tall

			# Measure center-to-center distance (same method for all note sizes)
			distance = abs(note_center_y - hit_zone_center_y)

			if distance < best_distance:
				best_distance = distance
				closest_note = note
	
	if closest_note:
		# Get note's actual height dynamically
		var note_height = 200.0  # Default
		if closest_note.has_node("NoteTemplate"):
			note_height = closest_note.get_node("NoteTemplate").size.y

		# Pass note position and hitzone position for edge-based checking
		var hit_quality = get_hit_quality_for_note(best_distance, closest_note, hit_zone_y)

		# Calculate effect position at note's center (dynamic for any note size)
		var effect_pos = closest_note.position + Vector2(100, note_height / 2.0)

		if hit_quality == "MISS":
			explode_note_at_position(closest_note, "black", 2, effect_pos)
			show_feedback_at_position(get_random_feedback_text("MISS"), effect_pos, true)
			process_miss()
		else:
			process_hit(hit_quality, closest_note, effect_pos)

		fade_out_note(closest_note)
		active_notes.erase(closest_note)

func get_hit_quality_for_note(distance: float, note: Node, hit_zone_y: float) -> String:
	# Get note's actual height dynamically
	var note_height = 200.0  # Default
	if note.has_node("NoteTemplate"):
		note_height = note.get_node("NoteTemplate").size.y

	# Calculate no-overlap threshold based on actual note size
	var note_half_height = note_height / 2.0
	var hitzone_half_height = 100.0  # HitZone is always 200px tall
	var no_overlap_threshold = note_half_height + hitzone_half_height

	# First check if completely outside HitZone (no overlap) = MISS
	if distance >= no_overlap_threshold:
		return "MISS"

	# For large notes (whole notes, half notes): Check if HitZone is COMPLETELY inside the note
	# by checking actual edge positions
	if note_height > 200:  # Larger than HitZone
		var note_top = note.position.y
		var note_bottom = note.position.y + note_height
		var hitzone_top = hit_zone_y
		var hitzone_bottom = hit_zone_y + 200.0

		# HitZone completely covered = PERFECT
		if note_top <= hitzone_top and note_bottom >= hitzone_bottom:
			return "PERFECT"

	# For quarter notes or partial coverage: use standard timing windows
	if distance <= PERFECT_WINDOW_BASE: return "PERFECT"
	elif distance <= GOOD_WINDOW: return "GOOD"
	elif distance <= OKAY_WINDOW: return "OKAY"
	else: return "OKAY"

func process_hit(quality: String, note: Node, effect_pos: Vector2):
	# Register hit with BattleManager (handles combo, groove, strength)
	# XP popup automatically shows via BattleManager.hit_registered signal
	BattleManager.register_hit(quality)

	var feedback_text = get_random_feedback_text(quality)

	match quality:
		"PERFECT":
			score += 100
			combo = BattleManager.get_combo_current()
			explode_note_at_position(note, "rainbow", 5, effect_pos)
			show_feedback_at_position(feedback_text, effect_pos, false)
			play_pecs_animation()
			player_jump()
		"GOOD":
			score += 50
			combo = BattleManager.get_combo_current()
			explode_note_at_position(note, get_track_color(note.track_key), 3, effect_pos)
			show_feedback_at_position(feedback_text, effect_pos, false)
		"OKAY":
			score += 25
			combo = BattleManager.get_combo_current()
			explode_note_at_position(note, get_track_color(note.track_key), 2, effect_pos)
			show_feedback_at_position(feedback_text, effect_pos, false)

	max_combo = BattleManager.get_combo_max()

func get_track_color(track_key: String) -> String:
	match track_key:
		"1": return "cyan"
		"2": return "magenta"
		"3": return "yellow"
		_: return "white"

func play_pecs_animation():
	if player_sprite and player_sprite.sprite_frames:
		if player_sprite.sprite_frames.has_animation("pecs"):
			if player_sprite.animation_finished.is_connected(_on_pecs_finished):
				player_sprite.animation_finished.disconnect(_on_pecs_finished)
			player_sprite.play("pecs")
			player_sprite.animation_finished.connect(_on_pecs_finished, CONNECT_ONE_SHOT)

func _on_pecs_finished():
	if player_sprite and player_sprite.sprite_frames:
		if player_sprite.sprite_frames.has_animation("idle"):
			player_sprite.play("idle")

func player_jump():
	if player_sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(player_sprite, "position:y", player_original_pos.y - 60, 0.25)
		tween.tween_property(player_sprite, "position:y", player_original_pos.y, 0.25).set_delay(0.25)

func trainer_jump():
	if trainer_sprite:
		trainer_sprite.pause()
		var ts = trainer_sprite  # Capture for lambda
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ts, "position:y", trainer_original_pos.y - 60, 0.25)
		tween.tween_property(ts, "position:y", trainer_original_pos.y, 0.25).set_delay(0.25)
		tween.tween_callback(func():
			if is_instance_valid(ts):
				ts.play()
		).set_delay(0.5)

func process_miss():
	# Register miss with BattleManager (handles combo reset, groove penalty, etc.)
	BattleManager.register_hit("MISS")
	combo = 0
	trainer_jump()

func get_random_feedback_text(quality: String) -> String:
	match quality:
		"PERFECT":
			var perfect_texts = ["Perfect!", "Wow!", "Super!", "Amazing!", "Awesome!"]
			return perfect_texts[randi() % perfect_texts.size()]
		"GOOD":
			var good_texts = ["Nice!", "Good!", "Decent!", "Alright!", "Not bad!"]
			return good_texts[randi() % good_texts.size()]
		"OKAY":
			var okay_texts = ["Almost!", "Close!", "Not quite!", "Barely!", "Off beat!"]
			return okay_texts[randi() % okay_texts.size()]
		"MISS":
			var miss_texts = ["Missed!", "Oops!", "Miss!", "Nope!", "Fail!"]
			return miss_texts[randi() % miss_texts.size()]
		_:
			return "?"

func explode_note_at_position(_note: Node, color_type: String, intensity: int, explosion_pos: Vector2):
	# Clamp explosion center to screen bounds so it's visible even if note is off-screen
	var viewport_size = get_viewport().get_visible_rect().size
	var note_center = Vector2(
		clamp(explosion_pos.x, 100, viewport_size.x - 100),
		clamp(explosion_pos.y, 100, viewport_size.y - 100)
	)
	var particle_count = intensity * 20

	for i in range(particle_count):
		var particle = ColorRect.new()
		var particle_size = randi_range(8, 25)
		particle.size = Vector2(particle_size, particle_size)
		particle.pivot_offset = particle.size / 2

		match color_type:
			"rainbow":
				var rainbow_colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.PURPLE, Color.MAGENTA, Color.PINK]
				particle.color = rainbow_colors[i % rainbow_colors.size()]
			"cyan":
				var cyan_shades = [Color.CYAN, Color.LIGHT_CYAN, Color.AQUA, Color.TURQUOISE]
				particle.color = cyan_shades[i % cyan_shades.size()]
			"magenta":
				var magenta_shades = [Color.MAGENTA, Color.DEEP_PINK, Color.HOT_PINK, Color.VIOLET]
				particle.color = magenta_shades[i % magenta_shades.size()]
			"yellow":
				var yellow_shades = [Color.YELLOW, Color.GOLD, Color.ORANGE, Color.LIGHT_YELLOW]
				particle.color = yellow_shades[i % yellow_shades.size()]
			"white":
				particle.color = Color.WHITE
			"black":
				var dark_colors = [Color.BLACK, Color.DIM_GRAY, Color.DARK_GRAY, Color.PURPLE]
				particle.color = dark_colors[i % dark_colors.size()]

		particle.rotation = randf() * TAU
		particle.position = note_center + Vector2(randi_range(-40, 40), randi_range(-40, 40))
		effects_layer.add_child(particle)

		# Capture particle in local variable for lambda
		var p = particle
		var tween = create_tween()
		tween.set_parallel(true)

		# Original explosion behavior: larger radius, longer duration
		var explosion_radius = 600 if color_type == "rainbow" else 450
		var random_direction = Vector2(randf_range(-explosion_radius, explosion_radius), randf_range(-explosion_radius, explosion_radius))
		var duration = randf_range(0.8, 1.5)

		tween.tween_property(p, "position", p.position + random_direction, duration)
		tween.tween_property(p, "rotation", p.rotation + randf_range(-TAU * 2, TAU * 2), duration)
		tween.tween_property(p, "modulate:a", 0.0, duration)
		tween.tween_property(p, "scale", Vector2(3.0, 3.0), duration * 0.2)
		tween.tween_property(p, "scale", Vector2(0.0, 0.0), duration * 0.8).set_delay(duration * 0.2)
		tween.tween_callback(func():
			if is_instance_valid(p):
				p.queue_free()
		).set_delay(duration)

# SIMPLE feedback function - all feedback fades at same rate
func show_feedback_at_position(text: String, note_pos: Vector2, flash_screen: bool):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.z_index = 300

	# note_pos passed in is the NOTE CENTER already
	var note_center = note_pos
	var desired_position = Vector2(note_center.x - 200, note_center.y - 100)
	var label_size = Vector2(400, 200)

	# Clamp to screen so feedback is always visible
	label.position = clamp_to_screen(desired_position, label_size)
	label.size = label_size
	effects_layer.add_child(label)
	
	if flash_screen:
		modulate = Color.RED
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# ALL feedback moves up and fades identically at the same rate
	# Capture label in local variable for lambda
	var lbl = label
	var move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(lbl, "position:y", lbl.position.y - 80, 0.8)
	move_tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
	move_tween.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	).set_delay(1.0)

func fade_out_note(note: Node):
	if is_instance_valid(note):
		# Stop the note from moving
		if note.has_method("stop_movement"):
			note.stop_movement()

		# Capture note in local variable for lambda
		var n = note
		# Fade out quickly
		var fade_tween = create_tween()
		fade_tween.tween_property(n, "modulate:a", 0.0, 0.3)
		fade_tween.tween_callback(func():
			if is_instance_valid(n):
				n.queue_free()
		)
