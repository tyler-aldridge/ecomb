extends Node2D

@onready var conductor = $Conductor
@onready var hit_zones = $HitZones
@onready var player_sprite = $TutorialUI/Player
@onready var trainer_sprite = $TutorialUI/Trainer

# Level data
@export var level_data_path: String = "res://data/levels/DivineFoxPlay-152BPM.json"
var level_data: Dictionary = {}
var processed_patterns: Dictionary = {}  # Stores pre-calculated beat positions for patterns

# Note spawning
var note_scene = preload("res://scenes/rhythm/Note.tscn")
var long_note_scene = preload("res://scenes/rhythm/LongNote.tscn")
var hit_zone_positions = {
	"1": Vector2(660.0, 650.0),
	"2": Vector2(860.0, 650.0),
	"3": Vector2(1060.0, 650.0)
}

# Spawn settings
const SPAWN_HEIGHT_ABOVE_TARGET = 1000.0
const NOTE_TRAVEL_TIME = 1.55

# Timing windows
const PERFECT_WINDOW = 20.0
const GOOD_WINDOW = 50.0
const OKAY_WINDOW = 100.0
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
var trainer_original_pos: Vector2

# Fade overlay
var fade_overlay: ColorRect

func _ready():
	# Load level data
	load_level_data()

	# Create fade overlay
	create_fade_overlay()
	fade_from_black()

	# Create effects layer
	effects_layer = Node2D.new()
	effects_layer.z_index = 100
	add_child(effects_layer)

	setup_hit_zone_borders()
	start_character_animations()
	conductor.beat.connect(_on_beat)

	# Start with beat offset
	await get_tree().create_timer(1.0).timeout
	conductor.play_with_beat_offset()

func load_level_data():
	var file = FileAccess.open(level_data_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			level_data = json.data
			print("Level data loaded: ", level_data.get("song_name", "Unknown"))

			# Pre-process patterns to calculate all beat positions
			if level_data.has("patterns"):
				for pattern in level_data["patterns"]:
					process_pattern(pattern)
		else:
			push_error("Failed to parse level data JSON: " + json.get_error_message())
	else:
		push_error("Failed to load level data from: " + level_data_path)

func process_pattern(pattern: Dictionary):
	var beats_per_bar = level_data.get("beats_per_bar", 4)
	var beat_start = pattern.get("beat_start", 0)
	var beat_end = pattern.get("beat_end", 0)

	# Simple interval pattern
	if pattern.has("interval") and not pattern.has("type"):
		var interval = pattern["interval"]
		for beat_pos in range(beat_start, beat_end + 1, interval):
			processed_patterns[beat_pos] = pattern

	# Complex bar-based pattern
	elif pattern.get("type") == "complex" and pattern.has("bars"):
		var bars_dict = pattern["bars"]

		# Find the first bar number to use as reference
		var first_bar_num = 999999
		for bar_str in bars_dict.keys():
			var bar_num = int(bar_str)
			if bar_num < first_bar_num:
				first_bar_num = bar_num

		for bar_str in bars_dict.keys():
			var bar_num = int(bar_str)
			var beats_in_bar = bars_dict[bar_str].get("beats", [])

			for half_beat in beats_in_bar:
				# Calculate absolute beat position
				# beat_start corresponds to first bar, beat 0
				var beat_pos = beat_start + (bar_num - first_bar_num) * beats_per_bar * 2 + half_beat
				processed_patterns[beat_pos] = pattern

	# Conditional pattern with special bars
	elif pattern.get("type") == "conditional":
		var default_interval = pattern.get("default_interval", 4)
		var special_bars_dict = pattern.get("special_bars", {})
		var reference_beat = pattern.get("reference_beat", beat_start)
		var reference_bar = pattern.get("reference_bar", 1)

		# Parse special bar ranges (e.g., "80-82")
		var special_bar_beats = {}
		for bar_range_str in special_bars_dict.keys():
			var beats_config = special_bars_dict[bar_range_str]
			var range_parts = bar_range_str.split("-")
			var start_bar = int(range_parts[0])
			var end_bar = int(range_parts[1]) if range_parts.size() > 1 else start_bar

			for bar_num in range(start_bar, end_bar + 1):
				special_bar_beats[bar_num] = beats_config.get("beats", [])

		# Process all beats in the range
		for beat_pos in range(beat_start, beat_end + 1):
			var adjusted_beat = beat_pos - reference_beat
			var current_bar = int(float(adjusted_beat) / (beats_per_bar * 2)) + reference_bar
			var half_beat_in_bar = adjusted_beat % (beats_per_bar * 2)

			# Check if this bar has special beats
			if special_bar_beats.has(current_bar):
				if half_beat_in_bar in special_bar_beats[current_bar]:
					processed_patterns[beat_pos] = pattern
			else:
				# Use default interval
				if beat_pos % default_interval == 0:
					processed_patterns[beat_pos] = pattern

func create_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.z_index = 1000
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_overlay)

func fade_from_black():
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
			if dialogue.get("beat_position") == beat_position:
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
			if countdown.get("beat_position") == beat_position:
				var countdown_type = countdown.get("type", "single")
				if countdown_type == "multi":
					var values = countdown.get("values", [])
					var interval = countdown.get("interval", 0.5)
					var size = countdown.get("size", 500)
					DialogManager.show_countdown(values, interval, size)
				elif countdown_type == "single":
					var text = countdown.get("text", "")
					var duration = countdown.get("duration", 1.0)
					var size = countdown.get("size", 500)
					var color_str = countdown.get("color", "white")
					var color = Color.WHITE
					if color_str == "red":
						color = Color.RED
					DialogManager.show_countdown_number(text, duration, size, color)

	# Process individual notes
	if level_data.has("notes"):
		for note_data in level_data["notes"]:
			if note_data.get("beat_position") == beat_position:
				var note_type = note_data.get("note", "quarter")
				spawn_note_by_type(note_type)

	# Process patterns (pre-calculated beats)
	if processed_patterns.has(beat_position):
		var pattern = processed_patterns[beat_position]
		var note_type = pattern.get("note", "quarter")
		spawn_note_by_type(note_type)

func handle_trigger(trigger_name: String):
	match trigger_name:
		"create_hit_zone_indicators":
			create_hit_zone_indicators()
		"fade_to_title":
			get_tree().create_timer(5.0).timeout.connect(fade_to_title)

func spawn_note_by_type(note_type: String):
	match note_type:
		"whole":
			spawn_ambient_note()
		"quarter":
			spawn_single_note()
		_:
			spawn_single_note()  # Default to quarter note

func create_hit_zone_indicators():
	var indicators_to_cleanup = []
	
	for i in range(3):
		var zone_key = str(i + 1)
		var pos = hit_zone_positions[zone_key]
		
		var border = Line2D.new()
		border.width = 5.0
		border.default_color = Color.YELLOW
		border.add_point(Vector2(0, 0))
		border.add_point(Vector2(200, 0))
		border.add_point(Vector2(200, 200))
		border.add_point(Vector2(0, 200))
		border.add_point(Vector2(0, 0))
		border.position = pos
		border.z_index = 350
		add_child(border)
		indicators_to_cleanup.append(border)
		
		var label = Label.new()
		label.text = zone_key
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 100)
		label.add_theme_color_override("font_color", Color.YELLOW)
		label.position = pos + Vector2(50, 50)
		label.size = Vector2(100, 100)
		label.z_index = 350
		add_child(label)
		indicators_to_cleanup.append(label)
		
		var tween = create_tween()
		tween.set_loops(70)
		tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.325)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.325)
	
	# Clean up after 10.4 seconds (16 loops * 0.65 seconds per loop)
	var cleanup_timer = get_tree().create_timer(10.4)
	cleanup_timer.timeout.connect(_cleanup_indicators.bind(indicators_to_cleanup))

func _cleanup_indicators(indicators: Array):
	for indicator in indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()

func fade_to_title():
	fade_overlay.modulate.a = 0.0
	var fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 2.0)
	fade_tween.tween_callback(change_to_title)

func change_to_title():
	GameManager.complete_tutorial()
	get_tree().change_scene_to_file("res://scenes/ui/title/MainTitle.tscn")

func spawn_ambient_note():
	var tracks = ["1", "2", "3"]
	var random_track = tracks[randi() % tracks.size()]
	var target_pos = hit_zone_positions[random_track]
	# (unchanged path math)
	var spawn_pos = Vector2(target_pos.x, target_pos.y - SPAWN_HEIGHT_ABOVE_TARGET - 600.0)
	
	var note = long_note_scene.instantiate()
	note.z_index = 50
	add_child(note)
	note.setup(random_track, spawn_pos, target_pos.y)
	note.set_travel_time(3.0)
	note.set_meta("is_ambient", true)
	active_notes.append(note)

func spawn_single_note():
	var tracks = ["1", "2", "3"]
	var random_track = tracks[randi() % tracks.size()]
	var target_pos = hit_zone_positions[random_track]
	var spawn_pos = Vector2(target_pos.x, target_pos.y - SPAWN_HEIGHT_ABOVE_TARGET)
	
	var note = note_scene.instantiate()
	note.z_index = 50
	add_child(note)
	note.setup(random_track, spawn_pos, target_pos.y)
	note.set_travel_time(NOTE_TRAVEL_TIME)
	active_notes.append(note)

func check_automatic_misses():
	for note in active_notes:
		if is_instance_valid(note):
			var hit_zone_y = hit_zone_positions[note.track_key].y
			if note.position.y > hit_zone_y + MISS_WINDOW:
				var is_ambient = note.has_meta("is_ambient")
				# FIX: compute effect_pos as the NOTE'S CENTER (not the hit zone)
				var effect_pos = Vector2()
				if is_ambient:
					effect_pos = note.position + Vector2(100, 400)  # 200x800 center
				else:
					effect_pos = note.position + Vector2(100, 100)  # 200x200 center
				
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
	
	active_notes = active_notes.filter(func(note): return is_instance_valid(note))
	
	for note in active_notes:
		if note.track_key == track_key:
			var is_ambient = note.has_meta("is_ambient")
			var distance = 999999.0
			
			if is_ambient:
				# For long notes, we need to check if hit zone overlaps with the note body
				var note_length = 800.0  # Increase this if your long notes are actually longer
				var note_top = note.position.y
				var note_bottom = note.position.y + note_length
				
				# Check if hit zone is anywhere within the long note
				if hit_zone_y >= note_top - 50 and hit_zone_y <= note_bottom + 50:  # Added some tolerance
					distance = 0  # Perfect hit when overlapping
				else:
					var distance_to_top = abs(hit_zone_y - note_top)
					var distance_to_bottom = abs(hit_zone_y - note_bottom)
					distance = min(distance_to_top, distance_to_bottom)
			else:
				# Regular note distance calculation
				distance = abs(note.position.y - hit_zone_y)
			
			if distance < best_distance:
				best_distance = distance
				closest_note = note
	
	if closest_note:
		var hit_quality = get_hit_quality_for_note(best_distance, closest_note)
		var is_ambient = closest_note.has_meta("is_ambient")
		var effect_pos = Vector2()
		if is_ambient:
			effect_pos = closest_note.position + Vector2(100, 400)
		else:
			effect_pos = closest_note.position + Vector2(100, 100)
		
		if hit_quality == "MISS":
			explode_note_at_position(closest_note, "black", 2, effect_pos)
			show_feedback_at_position(get_random_feedback_text("MISS"), effect_pos, true)
			process_miss()
		else:
			process_hit(hit_quality, closest_note, effect_pos)
		
		fade_out_note(closest_note)
		active_notes.erase(closest_note)

func get_hit_quality_for_note(distance: float, note: Node) -> String:
	var is_ambient = note.has_meta("is_ambient")
	
	if is_ambient:
		if distance == 0: return "PERFECT"
		elif distance <= 100: return "GOOD"
		elif distance <= 200: return "OKAY"
		else: return "MISS"
	else:
		if distance <= PERFECT_WINDOW * 2: return "PERFECT"
		elif distance <= GOOD_WINDOW * 2: return "GOOD"
		elif distance <= OKAY_WINDOW * 2: return "OKAY"
		else: return "MISS"

func process_hit(quality: String, note: Node, effect_pos: Vector2):
	var feedback_text = get_random_feedback_text(quality)
	
	match quality:
		"PERFECT":
			score += 100
			combo += 1
			explode_note_at_position(note, "rainbow", 5, effect_pos)
			show_feedback_at_position(feedback_text, effect_pos, false)
			play_pecs_animation()
			player_jump()
		"GOOD":
			score += 50
			combo += 1
			explode_note_at_position(note, get_track_color(note.track_key), 3, effect_pos)
			show_feedback_at_position(feedback_text, effect_pos, false)
		"OKAY":
			score += 25
			combo += 1
			explode_note_at_position(note, get_track_color(note.track_key), 2, effect_pos)
			show_feedback_at_position(feedback_text, effect_pos, false)
	
	if combo > max_combo:
		max_combo = combo

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
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(trainer_sprite, "position:y", trainer_original_pos.y - 60, 0.25)
		tween.tween_property(trainer_sprite, "position:y", trainer_original_pos.y, 0.25).set_delay(0.25)
		tween.tween_callback(trainer_sprite.play).set_delay(0.5)

func process_miss():
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

func explode_note_at_position(note: Node, color_type: String, intensity: int, explosion_pos: Vector2):
	var is_ambient = note.has_meta("is_ambient")
	# FIX: explosion_pos is already the NOTE CENTER; do not add extra (100,100)
	var note_center = explosion_pos
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
		
		var tween = create_tween()
		tween.set_parallel(true)
		
		var explosion_radius = 600 if color_type == "rainbow" else 450
		var random_direction = Vector2(randi_range(-explosion_radius, explosion_radius), randi_range(-explosion_radius, explosion_radius))
		var base_duration = 2.5 if is_ambient else 1.25
		var duration = randf_range(base_duration * 0.4, base_duration)
		
		tween.tween_property(particle, "position", particle.position + random_direction, duration)
		tween.tween_property(particle, "rotation", particle.rotation + randf_range(-TAU * 2, TAU * 2), duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration)
		tween.tween_property(particle, "scale", Vector2(3.0, 3.0), duration * 0.2)
		tween.tween_property(particle, "scale", Vector2(0.0, 0.0), duration * 0.8).set_delay(duration * 0.2)
		tween.tween_callback(particle.queue_free).set_delay(duration)

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
	label.position = Vector2(note_center.x - 200, note_center.y - 100)
	label.size = Vector2(400, 200)
	effects_layer.add_child(label)
	
	if flash_screen:
		modulate = Color.RED
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# ALL feedback moves up and fades identically at the same rate
	var move_tween = create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(label, "position:y", label.position.y - 80, 0.8)
	move_tween.tween_property(label, "modulate:a", 0.0, 1.0)
	move_tween.tween_callback(label.queue_free).set_delay(1.0)

func fade_out_note(note: Node):
	if is_instance_valid(note):
		var fade_tween = create_tween()
		fade_tween.tween_property(note, "modulate:a", 0.0, 1.0)
		fade_tween.tween_callback(note.queue_free)
