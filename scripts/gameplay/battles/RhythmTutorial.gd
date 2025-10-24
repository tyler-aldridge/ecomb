extends Node2D

@onready var conductor = $Conductor
@onready var hit_zones = $HitZones
@onready var player_sprite = $TutorialUI/Player
@onready var trainer_sprite = $TutorialUI/Trainer

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

# Options menu
const OPTIONS_MENU_SCENE = preload("res://scenes/ui/game/menus/GameOptionsMenu.tscn")
var options_menu: Control = null
var is_paused: bool = false

# Particle object pool
var particle_pool: Array[ColorRect] = []
const PARTICLE_POOL_SIZE = 200

# Note object pool
var note_pool: Dictionary = {"1": [], "2": [], "3": []}
var long_note_pool: Dictionary = {"1": [], "2": [], "3": []}
const NOTES_PER_TRACK = 30

# Tween cleanup tracking
var active_tweens: Array[Tween] = []

func _ready():
	# Create fade overlay
	create_fade_overlay()
	fade_from_black()
	
	# Create effects layer
	effects_layer = Node2D.new()
	effects_layer.z_index = 100
	add_child(effects_layer)

	# Initialize particle pool
	initialize_particle_pool()
	# Initialize note pools
	initialize_note_pools()

	setup_hit_zone_borders()
	start_character_animations()
	conductor.beat.connect(_on_beat)
	
	# Start with beat offset
	await get_tree().create_timer(1.0).timeout
	conductor.play_with_beat_offset()

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
	
	# Dialog timing - UPDATED with Muscle Beach style attitude
	if beat_position == -15:
		DialogManager.show_dialog("Yo chump! Open them ears, this only gets said once!", "trainer", 4.0)
		create_hit_zone_indicators()
	elif beat_position == 0:
		DialogManager.show_dialog("Hit 1, 2, or 3 on your keyboard with the beat! Miss it, and you might as well pack it up, cupcake!", "trainer", 5.0)
	elif beat_position == 104:
		DialogManager.show_dialog("Feelin’ the pump yet, sweaty palms?", "trainer", 8.0)
	elif beat_position == 160:
		DialogManager.show_dialog("Alright, tough guy, let’s see if you can handle the real grind. That was just the warmup!", "trainer", 8.0)
	elif beat_position == 208:
		DialogManager.show_countdown(["3", "2", "1", "GO!"], 0.5, 500)
	elif beat_position == 408:
		DialogManager.show_dialog("Hope you stretched, chump! Time for a curveball!", "trainer", 5.0)
	elif beat_position == 494:
		DialogManager.show_dialog("BWAHAHA! Gotcha scared for a sec, huh?", "trainer", 5.0)
	elif beat_position == 508:
		DialogManager.show_countdown_number("3", 1.0, 500, Color.WHITE)
	elif beat_position == 510:
		DialogManager.show_countdown_number("2", 1.0, 500, Color.WHITE)
	elif beat_position == 512:
		DialogManager.show_countdown_number("1", 1.0, 500, Color.WHITE)
	elif beat_position == 514:
		DialogManager.show_countdown_number("GO!", 1.0, 500, Color.RED)
	elif beat_position == 788:
		DialogManager.show_dialog("Not bad, rookie... but that was light weight, baby! See ya in the gym, scrub!", "trainer", 5.0)
		get_tree().create_timer(5.0).timeout.connect(fade_to_title)

	
	# Note spawning (unchanged)
	if beat_position == -8:
		spawn_ambient_note()
	elif beat_position == 50:
		spawn_ambient_note()
	elif beat_position == 98:
		spawn_ambient_note()
	elif beat_position == 146:
		spawn_ambient_note()
	elif beat_position >= 208 and beat_position <= 392:
		if beat_position % 4 == 0:
			spawn_single_note()
	elif beat_position == 400:
		spawn_single_note()
	elif beat_position >= 424 and beat_position <= 488:
		spawn_detailed_funky_rhythm(beat_position)
	elif beat_position >= 508 and beat_position <= 764:
		var adjusted_beat_for_bass = beat_position - 504
		var current_bar = float(adjusted_beat_for_bass) / 8.0 + 63.0
		var half_beat_in_bar = adjusted_beat_for_bass % 8
		if (int(current_bar) >= 80 and int(current_bar) <= 82) or (int(current_bar) >= 92 and int(current_bar) <= 95):
			if half_beat_in_bar == 0 or half_beat_in_bar == 2 or half_beat_in_bar == 4:
				spawn_single_note()
		elif beat_position % 4 == 0:
			spawn_single_note()

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

func pause_game():
	if is_paused:
		return

	is_paused = true
	get_tree().paused = true

	# Instantiate options menu
	options_menu = OPTIONS_MENU_SCENE.instantiate()
	options_menu.z_index = 1000
	options_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(options_menu)

	# Connect signals
	options_menu.closed.connect(unpause_game)
	options_menu.exit_to_title.connect(_on_exit_to_title)

	# Pause conductor (audio)
	if conductor:
		conductor.stream_paused = true

func unpause_game():
	if not is_paused:
		return

	is_paused = false
	get_tree().paused = false

	# Remove options menu
	if options_menu and is_instance_valid(options_menu):
		options_menu.queue_free()
		options_menu = null

	# Resume conductor (audio)
	if conductor:
		conductor.stream_paused = false

func _on_exit_to_title():
	# Unpause before changing scene
	get_tree().paused = false
	change_to_title()

func initialize_particle_pool():
	for i in range(PARTICLE_POOL_SIZE):
		var particle = ColorRect.new()
		particle.visible = false
		particle.z_index = 200
		effects_layer.add_child(particle)
		particle_pool.append(particle)

func get_particle() -> ColorRect:
	for particle in particle_pool:
		if not particle.visible:
			particle.visible = true
			particle.modulate.a = 1.0
			particle.scale = Vector2.ONE
			return particle
	# Pool exhausted, reuse first particle
	var particle = particle_pool[0]
	particle.visible = true
	particle.modulate.a = 1.0
	particle.scale = Vector2.ONE
	return particle

func return_particle(particle: ColorRect):
	if is_instance_valid(particle):
		particle.visible = false
		particle.modulate.a = 1.0
		particle.scale = Vector2.ONE

func initialize_note_pools():
	for track in ["1", "2", "3"]:
		for i in range(NOTES_PER_TRACK):
			# Regular notes
			var note = note_scene.instantiate()
			note.visible = false
			note.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(note)
			note_pool[track].append(note)

			# Long notes
			var long_note = long_note_scene.instantiate()
			long_note.visible = false
			long_note.process_mode = Node.PROCESS_MODE_PAUSABLE
			add_child(long_note)
			long_note_pool[track].append(long_note)

func get_note(track_key: String, is_long: bool = false) -> Area2D:
	var pool = long_note_pool if is_long else note_pool
	for note in pool[track_key]:
		if not note.visible:
			note.visible = true
			note.modulate.a = 1.0
			return note
	# Pool exhausted, reuse first note
	var note = pool[track_key][0]
	note.visible = true
	note.modulate.a = 1.0
	# Remove from active_notes if it's being reused
	if note in active_notes:
		active_notes.erase(note)
	return note

func return_note(note: Area2D):
	if is_instance_valid(note):
		note.visible = false
		note.modulate.a = 1.0
		note.position = Vector2.ZERO

func spawn_detailed_funky_rhythm(beat_pos: int):
	var adjusted_beat = beat_pos - 424
	var bar = float(adjusted_beat) / 8.0 + 53.0
	var half_beat_in_bar = adjusted_beat % 8
	
	match int(bar):
		53:
			if half_beat_in_bar == 0 or half_beat_in_bar == 2 or half_beat_in_bar == 3 or half_beat_in_bar == 6 or half_beat_in_bar == 7:
				spawn_single_note()
		54:
			if half_beat_in_bar == 0 or half_beat_in_bar == 3 or half_beat_in_bar == 7:
				spawn_single_note()
		55:
			if half_beat_in_bar == 1 or half_beat_in_bar == 3:
				spawn_single_note()
		58:
			if half_beat_in_bar == 0 or half_beat_in_bar == 4:
				spawn_single_note()
		59:
			if half_beat_in_bar == 0 or half_beat_in_bar == 4 or half_beat_in_bar == 7:
				spawn_single_note()
		60:
			if half_beat_in_bar == 1 or half_beat_in_bar == 3:
				spawn_single_note()

func spawn_ambient_note():
	var tracks = ["1", "2", "3"]
	var random_track = tracks[randi() % tracks.size()]
	var target_pos = hit_zone_positions[random_track]
	var spawn_pos = Vector2(target_pos.x, target_pos.y - SPAWN_HEIGHT_ABOVE_TARGET - 600.0)

	var note = get_note(random_track, true)
	note.z_index = 50
	note.setup(random_track, spawn_pos, target_pos.y)
	note.set_travel_time(3.0)
	note.set_meta("is_ambient", true)
	active_notes.append(note)

func spawn_single_note():
	var tracks = ["1", "2", "3"]
	var random_track = tracks[randi() % tracks.size()]
	var target_pos = hit_zone_positions[random_track]
	var spawn_pos = Vector2(target_pos.x, target_pos.y - SPAWN_HEIGHT_ABOVE_TARGET)

	var note = get_note(random_track, false)
	note.z_index = 50
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
	# Handle options menu toggle
	if event.is_action_pressed("options"):
		if not is_paused:
			pause_game()
		return

	# Don't process gameplay input if paused
	if is_paused:
		return

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
	var note_center = explosion_pos
	var particle_count = intensity * 20

	for i in range(particle_count):
		var particle = get_particle()
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
		tween.tween_callback(return_particle.bind(particle)).set_delay(duration)

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
		fade_tween.tween_callback(return_note.bind(note))
