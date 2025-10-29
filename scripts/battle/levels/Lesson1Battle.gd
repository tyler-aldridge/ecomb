extends Node2D

@onready var conductor = $Conductor
@onready var player_sprite = $TutorialUI/Player
@onready var opponent_sprite = $TutorialUI/Opponent

# Hitzones are now created universally by BattleManager
var hit_zones = []

# Level data
@export var level_data_path: String = "res://scripts/battle/data/Lesson1Data.json"
var level_data: Dictionary = {}

# Pre-sorted event arrays for fast lookups (avoids iterating all events every beat)
var sorted_notes: Array = []
var sorted_dialogues: Array = []
var sorted_countdowns: Array = []
var sorted_triggers: Array = []
var next_note_index: int = 0
var next_dialogue_index: int = 0
var next_countdown_index: int = 0
var next_trigger_index: int = 0

# ============================================================================
# UNIVERSAL BATTLE MECHANICS - See BattleManager autoload
# ============================================================================
# The following are now universal across all battles (defined in BattleManager):
# - NOTE_TYPE_CONFIG: Note scenes, travel times, spawn offsets
# - HIT_ZONE_POSITIONS: Lane positions for all 3 tracks
# - SPAWN_HEIGHT_ABOVE_TARGET: How far above screen notes spawn
# - HITZONE_HEIGHT: HitZone height constant
# - MISS_WINDOW: Automatic miss threshold
# - OVERLAP_PREVENTION_WINDOW: Lane overlap prevention window
# - UI_CONSTANTS: Fade durations, border widths, indicator properties
# - get_hit_quality_for_note(): Edge-based hit detection logic
# - choose_lane_avoiding_overlap(): Lane selection with overlap prevention
# - create_fade_out_tween(): Beat-based note fade animation
# - get_note_height(): Dynamic note height helper
# - create_hit_zone_indicators(): Universal yellow tutorial indicators
# - stop_hit_zone_indicators(): Remove tutorial indicators
# - Difficulty system: DIFFICULTY_PRESETS and thresholds
#
# To modify universal mechanics, edit scripts/autoload/BattleManager.gd
# ============================================================================

# Hit detection
var active_notes = []

# Effects layer
var effects_layer: Node2D

# Character positions
var player_original_pos: Vector2
var opponent_original_pos: Vector2

# Fade overlay
var fade_overlay: ColorRect

# Hit zone indicators
var hit_zone_indicator_nodes = []

# Battle UI elements
var ui_layer: CanvasLayer
var groove_bar: Control
var combo_display: Label
var xp_gain_display: Label
var battle_results: Control
var battle_failure: Control

# ============================================================================
# BAR/BEAT SYSTEM (Level-specific timing calculations)
# ============================================================================

func get_time_signature_info() -> Dictionary:
	"""Derive beats_per_bar and subdivision from standard time signature notation.

	Reads time_signature_numerator and time_signature_denominator from level_data.

	Rules:
	- Compound meters (6/8, 9/8, 12/8): numerator divisible by 3, denominator = 8, numerator >= 6
	  → beats_per_bar = numerator / 3, subdivision = 3
	- Simple meters (4/4, 3/4, 7/8, 5/4, etc.): everything else
	  → beats_per_bar = numerator, subdivision = 2

	Examples:
	- 4/4: beats_per_bar = 4, subdivision = 2 (simple)
	- 6/8: beats_per_bar = 2, subdivision = 3 (compound, felt as 2 dotted-quarter beats)
	- 7/8: beats_per_bar = 7, subdivision = 2 (simple, odd meter)
	- 12/8: beats_per_bar = 4, subdivision = 3 (compound, felt as 4 dotted-quarter beats)

	Returns:
		Dictionary with "beats_per_bar" and "subdivision" keys
	"""
	var numerator = int(level_data.get("time_signature_numerator", 4))
	var denominator = int(level_data.get("time_signature_denominator", 4))

	# Detect compound meters: 6/8, 9/8, 12/8 (divisible by 3, denominator 8, >= 6)
	var is_compound = (numerator % 3 == 0) and (denominator == 8) and (numerator >= 6)

	if is_compound:
		return {
			"beats_per_bar": floori(numerator / 3.0),
			"subdivision": 3
		}
	else:
		return {
			"beats_per_bar": numerator,
			"subdivision": 2
		}

func bar_beat_to_position(bar: int, beat: Variant) -> int:
	"""Convert Bar/Beat notation to beat_position (HIT time).

	Uses standard music time signature notation (numerator/denominator) from JSON.
	System automatically detects compound meters and calculates subdivision.

	Formula: beat_position = (bar - 1) * ticks_per_bar + (beat - 1) * subdivision - ticks_per_bar

	Time Signature Examples:
	- 4/4: beats_per_bar=4, subdivision=2, ticks_per_bar=8
	- 6/8: beats_per_bar=2, subdivision=3, ticks_per_bar=6 (compound: 2 dotted-quarter beats)
	- 7/8: beats_per_bar=7, subdivision=2, ticks_per_bar=14 (odd meter)
	- 12/8: beats_per_bar=4, subdivision=3, ticks_per_bar=12 (compound: 4 dotted-quarter beats)

	Args:
		bar: Bar number (e.g., 91)
		beat: Beat number or string with 'a' for AND (e.g., 3, "1a", 2.5)
			  For 4/4: beats 1, 2, 3, 4
			  For 6/8: beats 1, 2 (two dotted-quarter beats)
			  For 7/8: beats 1, 2, 3, 4, 5, 6, 7
			  AND notes: "1a", "2a" or 1.5, 2.5 (adds +1 tick)

	Returns:
		beat_position as integer

	Examples:
		4/4, Bar 91 Beat 3 → 716
		4/4, Bar 92 Beat "1a" → 721 (AND note)
		6/8, Bar 10 Beat 2 → 51
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

	# Get time signature info (automatically detects simple vs compound from numerator/denominator)
	var ts_info = get_time_signature_info()
	var beats_per_bar = ts_info["beats_per_bar"]
	var subdivision = ts_info["subdivision"]
	var ticks_per_bar = beats_per_bar * subdivision

	# Calculate beat position using time signature subdivision
	var base_pos = (bar - 1) * ticks_per_bar + (int(beat_num) - 1) * subdivision - ticks_per_bar

	# Add 1 tick for AND notes (subdivision offset)
	if beat_num != int(beat_num):  # Has decimal (e.g., 1.5)
		base_pos += 1

	return base_pos

func _ready():
	# Load level data
	load_level_data()

	# Configure conductor from level data
	if level_data.has("bpm"):
		var loaded_bpm = float(level_data["bpm"])
		# Validate BPM to prevent division by zero
		if loaded_bpm <= 0:
			push_error("Invalid BPM in level data: " + str(loaded_bpm) + ". Using default 120.")
			loaded_bpm = 120.0
		conductor.bpm = loaded_bpm
		conductor.seconds_per_beat = 60.0 / conductor.bpm
		# Set BPM in BattleManager for UI animations (groove bar, background)
		BattleManager.current_bpm = conductor.bpm
	if level_data.has("beats_before_start"):
		conductor.beats_before_start = int(level_data["beats_before_start"])

	# Configure time signature subdivision from standard notation (e.g., 4/4, 6/8, 7/8)
	# Automatically detects simple vs compound meters
	var ts_info = get_time_signature_info()
	conductor.subdivision = ts_info["subdivision"]

	if level_data.has("audio_file"):
		var audio_path = level_data["audio_file"]
		# Use MusicManager for instant, preloaded music (no web stuttering!)
		var audio_stream = MusicManager.get_music_by_path(audio_path)
		if audio_stream:
			conductor.stream = audio_stream
		else:
			push_error("Failed to get music from MusicManager: " + audio_path)

	# Calculate max possible strength (assuming all PERFECT hits with full combo)
	# PERFECT base = 10, but with combo multipliers it scales up
	var notes_array = level_data.get("notes", [])
	if notes_array.size() == 0:
		push_warning("No notes found in level data! Battle may not function correctly.")
	var total_notes = notes_array.size()

	# Calculate max strength accounting for combo multipliers:
	# 0-9 hits: 10 * 1.0 = 10 each
	# 10-19 hits: 10 * 1.5 = 15 each
	# 20-29 hits: 10 * 2.0 = 20 each
	# 30-39 hits: 10 * 2.5 = 25 each
	# 40+ hits: 10 * 3.0 = 30 each
	var max_strength = 0
	for i in range(total_notes):
		if i < 10:
			max_strength += 10  # 1.0x multiplier
		elif i < 20:
			max_strength += 15  # 1.5x multiplier
		elif i < 30:
			max_strength += 20  # 2.0x multiplier
		elif i < 40:
			max_strength += 25  # 2.5x multiplier
		else:
			max_strength += 30  # 3.0x multiplier (max)

	# Start battle with BattleManager
	var battle_data = {
		"battle_id": level_data.get("battle_id", ""),
		"battle_level": level_data.get("battle_level", 1),
		"battle_type": level_data.get("battle_type", "story"),
		"groove_start": level_data.get("groove_start", 50.0),
		"groove_miss_penalty": level_data.get("groove_miss_penalty", 10.0),
		"max_strength": max_strength
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
	await get_tree().create_timer(BattleManager.BATTLE_START_DELAY).timeout
	conductor.play_with_beat_offset()

func create_battle_ui():
	"""Instantiate and add battle UI elements to a CanvasLayer."""
	# Create UI layer for proper screen-space rendering
	ui_layer = CanvasLayer.new() 
	ui_layer.layer = 100
	add_child(ui_layer)

	# Groove bar (full width at top)
	var groove_bar_scene = preload("res://scenes/ui/battle/GrooveBar.tscn")
	groove_bar = groove_bar_scene.instantiate()
	ui_layer.add_child(groove_bar)

	# Universal character displays (combo below groove bar, XP on player)
	# Uses BattleManager's universal setup for consistent positioning across all battles
	var displays = BattleManager.setup_battle_character_displays(player_sprite, opponent_sprite, ui_layer)
	combo_display = displays.get("combo_display")
	xp_gain_display = displays.get("xp_display")
	hit_zones = displays.get("hitzones", [])

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

			# Get spawn_offset from config (fixed per note type)
			var spawn_offset = BattleManager.NOTE_TYPE_CONFIG[note_type]["spawn_offset"] if BattleManager.NOTE_TYPE_CONFIG.has(note_type) else 8
			var spawn_position = hit_position - spawn_offset

			# Store spawn position for use in _on_beat
			note_data["spawn_position"] = spawn_position

	# Pre-sort all event arrays by beat_position for fast sequential lookups
	if level_data.has("notes"):
		sorted_notes = level_data["notes"].duplicate()
		sorted_notes.sort_custom(func(a, b): return a.get("spawn_position", 0) < b.get("spawn_position", 0))

	if level_data.has("dialogue"):
		sorted_dialogues = level_data["dialogue"].duplicate()
		sorted_dialogues.sort_custom(func(a, b): return a.get("beat_position", 0) < b.get("beat_position", 0))

	if level_data.has("countdowns"):
		sorted_countdowns = level_data["countdowns"].duplicate()
		sorted_countdowns.sort_custom(func(a, b): return a.get("beat_position", 0) < b.get("beat_position", 0))

	if level_data.has("triggers"):
		sorted_triggers = level_data["triggers"].duplicate()
		sorted_triggers.sort_custom(func(a, b): return a.get("beat_position", 0) < b.get("beat_position", 0))

func create_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.z_index = 1000
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func fade_from_black():
	"""Fade from black overlay with smooth easing."""
	if not is_instance_valid(fade_overlay):
		return
	fade_overlay.modulate.a = 1.0
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, BattleManager.FADE_FROM_BLACK_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func setup_hit_zone_borders():
	"""Add white borders to all hit zones using universal BattleManager constants."""
	for i in range(hit_zones.size()):
		var hit_zone = hit_zones[i]
		if is_instance_valid(hit_zone):
			hit_zone.color = Color(1, 1, 1, 0)

			var border = Line2D.new()
			border.width = BattleManager.HITZONE_BORDER_WIDTH
			border.default_color = BattleManager.HITZONE_BORDER_COLOR
			border.add_point(Vector2(0, 0))
			border.add_point(Vector2(BattleManager.HITZONE_HEIGHT, 0))
			border.add_point(Vector2(BattleManager.HITZONE_HEIGHT, BattleManager.HITZONE_HEIGHT))
			border.add_point(Vector2(0, BattleManager.HITZONE_HEIGHT))
			border.add_point(Vector2(0, 0))
			hit_zone.add_child(border)

func start_character_animations():
	# Store original positions FIRST before any animation changes
	if player_sprite:
		player_original_pos = player_sprite.position
	if opponent_sprite:
		opponent_original_pos = opponent_sprite.position

	# Now play idle animations (sprites already have animations set in scene)
	if player_sprite:
		if player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("idle"):
			player_sprite.play("idle")

	if opponent_sprite:
		if opponent_sprite.sprite_frames and opponent_sprite.sprite_frames.has_animation("idle"):
			opponent_sprite.play("idle")

func _on_beat(beat_position: int):
	check_automatic_misses()

	# Process dialogue events (optimized: check only next pending dialogue)
	while next_dialogue_index < sorted_dialogues.size():
		var dialogue = sorted_dialogues[next_dialogue_index]
		var dialogue_beat = int(dialogue.get("beat_position", 0))
		if dialogue_beat > beat_position:
			break
		if dialogue_beat == beat_position:
			var text = dialogue.get("text", "")
			var character = dialogue.get("character", "opponent")
			var duration = dialogue.get("duration", 3.0)
			DialogManager.show_dialog(text, character, duration)

			# Handle triggers
			if dialogue.has("triggers"):
				handle_trigger(dialogue["triggers"])
		next_dialogue_index += 1

	# Process countdown events (optimized: check only next pending countdown)
	while next_countdown_index < sorted_countdowns.size():
		var countdown = sorted_countdowns[next_countdown_index]
		var countdown_beat = int(countdown.get("beat_position", 0))
		if countdown_beat > beat_position:
			break
		if countdown_beat == beat_position:
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
		next_countdown_index += 1

	# Process trigger events (optimized: check only next pending trigger)
	while next_trigger_index < sorted_triggers.size():
		var trigger = sorted_triggers[next_trigger_index]
		var trigger_beat = int(trigger.get("beat_position", 0))
		if trigger_beat > beat_position:
			break
		if trigger_beat == beat_position:
			var trigger_name = trigger.get("trigger", "")
			handle_trigger(trigger_name)
		next_trigger_index += 1

	# Process notes (optimized: check only next pending notes)
	while next_note_index < sorted_notes.size():
		var note_data = sorted_notes[next_note_index]
		var note_spawn = int(note_data.get("spawn_position", 0))
		if note_spawn > beat_position:
			break
		if note_spawn == beat_position:
			var note_type = note_data.get("note", "quarter")
			var lane = note_data.get("lane", "random")
			spawn_note_by_type(note_type, lane, note_spawn)
		next_note_index += 1

func handle_trigger(trigger_name: String):
	"""Handle trigger events using universal BattleManager functions where possible."""
	match trigger_name:
		"create_hit_zone_indicators":
			# Use universal BattleManager function
			hit_zone_indicator_nodes = BattleManager.create_hit_zone_indicators(ui_layer, self)
		"stop_hit_zone_indicators":
			# Use universal BattleManager function
			BattleManager.stop_hit_zone_indicators(hit_zone_indicator_nodes, self)
			hit_zone_indicator_nodes = []
		"fade_to_title":
			fade_to_title()

func spawn_note_by_type(note_type: String, lane: String = "random", spawn_beat_position: int = 0):
	"""Unified note spawning function that uses BattleManager.NOTE_TYPE_CONFIG for scalability

	Args:
		note_type: Type of note (whole, half, quarter, eighth, etc.)
		lane: Lane designation - "random", "1", "2", "3", etc. Defaults to "random"
		spawn_beat_position: Beat position for overlap detection (from JSON spawn_position)
	"""
	if not BattleManager.NOTE_TYPE_CONFIG.has(note_type):
		push_warning("Unknown note type '" + note_type + "', defaulting to 'quarter'")
		note_type = "quarter"

	var config = BattleManager.NOTE_TYPE_CONFIG[note_type]

	# Choose lane: use designated lane if valid, otherwise use smart random selection
	var chosen_track: String
	if lane != "random" and BattleManager.HIT_ZONE_POSITIONS.has(lane):
		chosen_track = lane  # Use designated lane from note data
	else:
		chosen_track = BattleManager.choose_lane_avoiding_overlap(spawn_beat_position)  # Smart random with overlap prevention

	var target_pos = BattleManager.HIT_ZONE_POSITIONS[chosen_track]

	# Instantiate note from config
	var note = config["scene"].instantiate()
	add_child(note)

	# Get note's actual height dynamically using universal helper
	var note_height = BattleManager.get_note_height(note)

	# Calculate spawn position: center-align all notes with HitZone
	# Adjust spawn position so note's CENTER aligns with HitZone center (not top/bottom edge)
	var center_offset = (note_height - 200.0) / 2.0
	var spawn_pos = Vector2(target_pos.x, target_pos.y - BattleManager.SPAWN_HEIGHT_ABOVE_TARGET - center_offset - 200)


	note.z_index = 50
	note.setup(chosen_track, spawn_pos, target_pos.y)

	# Calculate travel_time from spawn_offset and BPM
	# This makes notes fall faster for fast songs, slower for slow songs
	var spawn_offset = config["spawn_offset"]
	var travel_time = spawn_offset * 30.0 / conductor.bpm

	# Pass the actual distance the note needs to travel
	var actual_distance = target_pos.y - spawn_pos.y
	note.set_travel_time_and_distance(travel_time, actual_distance)

	note.set_meta("note_type", note_type)  # Use note_type instead of is_ambient
	active_notes.append(note)

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

	# Fade to black using universal BattleManager duration
	if not is_instance_valid(fade_overlay):
		if battle_succeeded and is_instance_valid(battle_results):
			battle_results.show_battle_results(results)
		else:
			change_to_title()
		return

	fade_overlay.modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, BattleManager.FADE_TO_BLACK_DURATION)

	# Capture variables to avoid freed object errors
	var succeeded = battle_succeeded
	var results_copy = results.duplicate()
	var br = battle_results

	# Use bind instead of lambda to avoid capture issues
	fade_tween.tween_callback(_show_battle_results_after_fade.bind(succeeded, results_copy, br))

func _show_battle_results_after_fade(succeeded: bool, results_copy: Dictionary, br: Control):
	"""Callback after fade to black - show results or go to title."""
	if succeeded and is_instance_valid(br):
		br.show_battle_results(results_copy)
	elif is_instance_valid(self):
		change_to_title()

func _on_battle_failed():
	# Hide battle UI elements (combo display and groove bar)
	hide_battle_ui()

	"""Called when groove reaches 0% - battle failure."""
	# Stop the music
	if conductor:
		conductor.stop()

	# BattleFailure dialog automatically shows via BattleManager.battle_failed signal

func hide_battle_ui():
	"""Hide combo display, groove bar, and hitzones when battle ends."""
	if combo_display:
		combo_display.visible = false
	if groove_bar:
		groove_bar.visible = false
	# Hide hitzones before battle results
	for hitzone in hit_zones:
		if is_instance_valid(hitzone):
			hitzone.visible = false

func change_to_title():
	if is_instance_valid(GameManager):
		GameManager.complete_tutorial()
	if is_instance_valid(get_tree()):
		get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func check_automatic_misses():
	"""Check if any notes have passed the hit zone and register automatic misses."""
	# CRITICAL: Collect notes to remove first, then process them
	# Never modify an array while iterating over it!
	var notes_to_remove = []

	for note in active_notes:
		if is_instance_valid(note):
			var hit_zone_y = BattleManager.HIT_ZONE_POSITIONS[note.track_key].y
			if note.position.y > hit_zone_y + BattleManager.MISS_WINDOW:
				notes_to_remove.append(note)

	# Now process the missed notes outside the iteration
	for note in notes_to_remove:
		if is_instance_valid(note):
			# Get note's actual height dynamically using universal helper
			var note_height = BattleManager.get_note_height(note)

			# Calculate effect position at note's center (dynamic for any note size)
			var effect_pos = note.position + Vector2(100, note_height / 2.0)

			BattleManager.explode_note_at_position(note, "black", 2, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(BattleManager.get_random_feedback_text("MISS"), effect_pos, true, effects_layer, self)
			process_miss()
			BattleManager.create_miss_fade_tween(note)
			active_notes.erase(note)

func _unhandled_input(event):
	"""Handle keyboard input dynamically based on number of lanes in BattleManager.HIT_ZONE_POSITIONS."""
	if event is InputEventKey and event.pressed:
		# Map keycodes to lane keys dynamically (supports 1-9 lanes)
		var keycode_to_lane = {
			KEY_1: "1",
			KEY_2: "2",
			KEY_3: "3",
			KEY_4: "4",
			KEY_5: "5",
			KEY_6: "6",
			KEY_7: "7",
			KEY_8: "8",
			KEY_9: "9"
		}

		# Check if this keycode maps to a valid lane
		if keycode_to_lane.has(event.keycode):
			var lane_key = keycode_to_lane[event.keycode]
			# Only handle input if this lane exists in BattleManager configuration
			if BattleManager.HIT_ZONE_POSITIONS.has(lane_key):
				handle_input(lane_key)

func handle_input(track_key: String):
	flash_hit_zone(track_key)
	check_hit(track_key)

func flash_hit_zone(track_key: String):
	var zone_index = int(track_key) - 1  # Convert "1", "2", "3" to 0, 1, 2
	if zone_index >= 0 and zone_index < hit_zones.size():
		var hit_zone_node = hit_zones[zone_index]
		if is_instance_valid(hit_zone_node):
			# Capture hit_zone_node to avoid lambda issues when tween fires
			var zone = hit_zone_node
			zone.modulate = Color.WHITE
			var flash_tween = create_tween()
			flash_tween.tween_property(zone, "modulate", Color(1, 1, 1, 1), 0.1)

func check_hit(track_key: String):
	var hit_zone_y = BattleManager.HIT_ZONE_POSITIONS[track_key].y
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

			# Get note's actual height dynamically using universal helper
			var note_height = BattleManager.get_note_height(note)

			# Calculate centers dynamically based on actual note size
			var note_center_y = note.position.y + (note_height / 2.0)
			var hit_zone_center_y = hit_zone_y + (BattleManager.HITZONE_HEIGHT / 2.0)

			# Measure center-to-center distance (same method for all note sizes)
			distance = abs(note_center_y - hit_zone_center_y)

			if distance < best_distance:
				best_distance = distance
				closest_note = note

	if closest_note:
		# Get note's actual height dynamically using universal helper
		var note_height = BattleManager.get_note_height(closest_note)

		# Pass note and hitzone position for edge-based checking
		var hit_quality = BattleManager.get_hit_quality_for_note(closest_note, hit_zone_y)

		# Calculate effect position at note's center (dynamic for any note size)
		var effect_pos = closest_note.position + Vector2(100, note_height / 2.0)

		if hit_quality == "MISS":
			BattleManager.explode_note_at_position(closest_note, "black", 2, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(BattleManager.get_random_feedback_text("MISS"), effect_pos, true, effects_layer, self)
			process_miss()
			# Use fast black fade for misses
			BattleManager.create_miss_fade_tween(closest_note)
		else:
			process_hit(hit_quality, closest_note, effect_pos)
			# Use normal fade for hits
			BattleManager.create_fade_out_tween(closest_note, conductor.bpm)

		active_notes.erase(closest_note)

func process_hit(quality: String, note: Node, effect_pos: Vector2):
	# Register hit with BattleManager (handles combo, groove, strength)
	# XP popup automatically shows via BattleManager.hit_registered signal
	BattleManager.register_hit(quality)

	var feedback_text = BattleManager.get_random_feedback_text(quality)

	match quality:
		"PERFECT":
			BattleManager.explode_note_at_position(note, "rainbow", 5, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)
			BattleManager.animate_player_hit(player_sprite, player_original_pos, quality, self)
		"GOOD":
			BattleManager.explode_note_at_position(note, BattleManager.get_track_color(note.track_key), 3, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)
		"OKAY":
			BattleManager.explode_note_at_position(note, BattleManager.get_track_color(note.track_key), 2, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)

func process_miss():
	# Register miss with BattleManager (handles combo reset, groove penalty, etc.)
	BattleManager.register_hit("MISS")
	BattleManager.animate_opponent_miss(opponent_sprite, opponent_original_pos, self)
