extends Node2D

@onready var conductor = $Conductor
@onready var hit_zones = $HitZones
@onready var player_sprite = $TutorialUI/Player
@onready var opponent_sprite = $TutorialUI/Opponent

# Level data
@export var level_data_path: String = "res://scripts/battle/data/Lesson1Data.json"
var level_data: Dictionary = {}

# ============================================================================
# UNIVERSAL BATTLE MECHANICS - See BattleManager autoload
# ============================================================================
# The following are now universal across all battles (defined in BattleManager):
# - NOTE_TYPE_CONFIG: Note scenes, travel times, spawn offsets
# - HIT_ZONE_POSITIONS: Lane positions for all 3 tracks
# - SPAWN_HEIGHT_ABOVE_TARGET: How far above screen notes spawn
# - HITZONE_HEIGHT: HitZone height constant
# - OVERLAP_PREVENTION_WINDOW: Lane overlap prevention window
# - get_hit_quality_for_note(): Edge-based hit detection logic
# - choose_lane_avoiding_overlap(): Lane selection with overlap prevention
# - create_fade_out_tween(): Beat-based note fade animation
# - Difficulty system: DIFFICULTY_PRESETS and thresholds
#
# To modify universal mechanics, edit scripts/autoload/BattleManager.gd
# ============================================================================

# Miss threshold for notes that passed HitZone completely
const MISS_WINDOW = 150.0

# Hit detection
var active_notes = []

# Scoring
var score = 0
var combo = 0
var max_combo = 0

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
var groove_bar: Control
var combo_display: Label
var xp_gain_display: Label
var battle_results: Control
var battle_failure: Control

# ============================================================================
# BAR/BEAT SYSTEM (Level-specific timing calculations)
# ============================================================================

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
	# Apply background shader
	apply_background_shader()

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

	# Calculate max possible strength (assuming all PERFECT hits)
	# PERFECT = 30 strength per note (from BattleManager.HIT_VALUES)
	var total_notes = level_data.get("notes", []).size()
	var max_strength = total_notes * 30  # 30 is PERFECT strength value

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
	await get_tree().create_timer(1.0).timeout
	conductor.play_with_beat_offset()

func apply_background_shader():
	"""Apply slow-moving swirl shader to background."""
	var background = $TutorialUI/Background
	if background:
		var shader = load("res://assets/shaders/background_swirl.gdshader")
		if shader:
			var material = ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("speed", 0.5)
			background.material = material

	# Apply color invert shader to opponent
	if opponent_sprite:
		var invert_shader = load("res://assets/shaders/color_invert.gdshader")
		if invert_shader:
			var invert_material = ShaderMaterial.new()
			invert_material.shader = invert_shader
			opponent_sprite.material = invert_material

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

	# Universal character displays (combo below groove bar, XP on player)
	# Uses BattleManager's universal setup for consistent positioning across all battles
	var displays = BattleManager.setup_battle_character_displays(player_sprite, opponent_sprite, ui_layer)
	combo_display = displays.get("combo_display")
	xp_gain_display = displays.get("xp_display")

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
			var spawn_offset = BattleManager.NOTE_TYPE_CONFIG[note_type]["spawn_offset"] if BattleManager.NOTE_TYPE_CONFIG.has(note_type) else 8
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

	if opponent_sprite:
		opponent_original_pos = opponent_sprite.position
		if opponent_sprite.sprite_frames and opponent_sprite.sprite_frames.has_animation("idle"):
			opponent_sprite.play("idle")

func _on_beat(beat_position: int):
	check_automatic_misses()

	# Process dialogue events
	if level_data.has("dialogue"):
		for dialogue in level_data["dialogue"]:
			if int(dialogue.get("beat_position", 0)) == beat_position:
				var text = dialogue.get("text", "")
				var character = dialogue.get("character", "opponent")
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
	"""Unified note spawning function that uses BattleManager.NOTE_TYPE_CONFIG for scalability"""
	if not BattleManager.NOTE_TYPE_CONFIG.has(note_type):
		push_warning("Unknown note type '" + note_type + "', defaulting to 'quarter'")
		note_type = "quarter"

	var config = BattleManager.NOTE_TYPE_CONFIG[note_type]
	var current_beat = conductor.song_position_in_beats if conductor else 0
	var random_track = BattleManager.choose_lane_avoiding_overlap(current_beat)
	var target_pos = BattleManager.HIT_ZONE_POSITIONS[random_track]

	# Instantiate note from config
	var note = config["scene"].instantiate()
	add_child(note)

	# Get note's actual height dynamically for scalable spawn positioning
	var note_height = 200.0  # Default
	if note.has_node("NoteTemplate"):
		note_height = note.get_node("NoteTemplate").size.y

	# Calculate spawn position: center-align all notes with HitZone
	# Adjust spawn position so note's CENTER aligns with HitZone center (not top/bottom edge)
	var center_offset = (note_height - 200.0) / 2.0
	var spawn_pos = Vector2(target_pos.x, target_pos.y - BattleManager.SPAWN_HEIGHT_ABOVE_TARGET - center_offset)

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
		var pos = BattleManager.HIT_ZONE_POSITIONS[zone_key]

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

func check_automatic_misses():
	for note in active_notes:
		if is_instance_valid(note):
			var hit_zone_y = BattleManager.HIT_ZONE_POSITIONS[note.track_key].y
			if note.position.y > hit_zone_y + MISS_WINDOW:
				# Get note's actual height dynamically
				var note_height = 200.0  # Default
				if note.has_node("NoteTemplate"):
					note_height = note.get_node("NoteTemplate").size.y

				# Calculate effect position at note's center (dynamic for any note size)
				var effect_pos = note.position + Vector2(100, note_height / 2.0)

				BattleManager.explode_note_at_position(note, "black", 2, effect_pos, effects_layer, self)
				BattleManager.show_feedback_at_position(BattleManager.get_random_feedback_text("MISS"), effect_pos, true, effects_layer, self)
				process_miss()
				BattleManager.create_miss_fade_tween(note)
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
		var hit_quality = BattleManager.get_hit_quality_for_note(best_distance, closest_note, hit_zone_y)

		# Calculate effect position at note's center (dynamic for any note size)
		var effect_pos = closest_note.position + Vector2(100, note_height / 2.0)

		if hit_quality == "MISS":
			BattleManager.explode_note_at_position(closest_note, "black", 2, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(BattleManager.get_random_feedback_text("MISS"), effect_pos, true, effects_layer, self)
			process_miss()
		else:
			process_hit(hit_quality, closest_note, effect_pos)

		BattleManager.create_fade_out_tween(closest_note, conductor.bpm)
		active_notes.erase(closest_note)

func process_hit(quality: String, note: Node, effect_pos: Vector2):
	# Register hit with BattleManager (handles combo, groove, strength)
	# XP popup automatically shows via BattleManager.hit_registered signal
	BattleManager.register_hit(quality)

	var feedback_text = BattleManager.get_random_feedback_text(quality)

	match quality:
		"PERFECT":
			score += 100
			combo = BattleManager.get_combo_current()
			BattleManager.explode_note_at_position(note, "rainbow", 5, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)
			BattleManager.animate_player_hit(player_sprite, player_original_pos, quality, self)
		"GOOD":
			score += 50
			combo = BattleManager.get_combo_current()
			BattleManager.explode_note_at_position(note, BattleManager.get_track_color(note.track_key), 3, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)
		"OKAY":
			score += 25
			combo = BattleManager.get_combo_current()
			BattleManager.explode_note_at_position(note, BattleManager.get_track_color(note.track_key), 2, effect_pos, effects_layer, self)
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, effects_layer, self)

	max_combo = BattleManager.get_combo_max()

func process_miss():
	# Register miss with BattleManager (handles combo reset, groove penalty, etc.)
	BattleManager.register_hit("MISS")
	combo = 0
	BattleManager.animate_opponent_miss(opponent_sprite, opponent_original_pos, self)

