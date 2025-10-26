extends Node

# Signals
signal request_save
signal request_load(slot: int)
signal scene_changed(path: String)

# Game version and data
var version := "0.1.0"
var profile_id := ""
var run_id := ""

# Player data - enhanced for rhythm game
var player_data := {
	"name": "",
	"favorite_thing": "",
	"selected_character": "",
	"hp": 100,
	"max_hp": 100,
	"strength": 0,  # Total Strength (XP) earned
	"level": 1,
	"inventory": [],
	"position": Vector2.ZERO,
	"current_scene": "",
	"tutorial_completed": false,
	"completed_story_battles": {},  # {"battle_id": max_strength_earned}
}

# Settings storage - enhanced with rhythm settings
var settings = {
	"master_volume": 100,
	"music_volume": 100,
	"sound_volume": 100,
	"rhythm_timing_offset": 0,  # For audio latency compensation (milliseconds, negative = notes spawn earlier)
	"fullscreen": false,
	"show_fps": false,
	"difficulty": "normal"  # easy, normal, hard
}

# File paths
const SETTINGS_FILE = "user://settings.save"
const SAVE_DIR = "user://saves"

# ============================================================================
# STRENGTH (XP) SYSTEM - Level Progression
# ============================================================================
# Total Strength required to reach each level (cumulative)
# Level 10 requires 5,000,000 total Strength
const LEVEL_THRESHOLDS = [
	0,          # Level 1 (start)
	40000,      # Level 2
	96000,      # Level 3 (40k + 56k)
	174000,     # Level 4 (96k + 78k)
	284000,     # Level 5 (174k + 110k)
	438000,     # Level 6 (284k + 154k)
	654000,     # Level 7 (438k + 216k)
	956000,     # Level 8 (654k + 302k)
	1379000,    # Level 9 (956k + 423k)
	2000000     # Level 10 (1,379k + 621k) - FINAL LEVEL
]

# Strength required per level (for display purposes)
const STRENGTH_PER_LEVEL = [
	0,       # Level 1 (start)
	40000,   # Level 1 → 2
	56000,   # Level 2 → 3
	78000,   # Level 3 → 4
	110000,  # Level 4 → 5
	154000,  # Level 5 → 6
	216000,  # Level 6 → 7
	302000,  # Level 7 → 8
	423000,  # Level 8 → 9
	621000   # Level 9 → 10
]

const MAX_LEVEL = 10

# Signals for level progression
signal strength_gained(amount: int, total: int)
signal level_up(new_level: int)

# FPS Display
var fps_label: Label = null

func _ready():
	print("GameManager loading...")
	# Create saves directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if dir == null:
		DirAccess.make_dir_recursive_absolute("user://")
		dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	
	load_settings()
	apply_audio_settings()
	apply_display_settings()
	
	# Create FPS display overlay
	create_fps_display()
	
	if OS.has_feature("web"):
		Engine.time_scale = 1.0
		# Increase audio buffer size for web
		AudioServer.set_bus_effect_enabled(0, 0, true)
	
	print("GameManager loaded successfully")

# ===== NEW: Player Data Management =====
func set_player_name(player_name: String):
	player_data["name"] = player_name

func set_favorite_thing(favorite: String):
	player_data["favorite_thing"] = favorite

func set_selected_character(character: String):
	player_data["selected_character"] = character

func complete_tutorial():
	player_data["tutorial_completed"] = true

# ============================================================================
# STRENGTH (XP) AND LEVEL SYSTEM
# ============================================================================

func add_strength(amount: int):
	"""Award Strength (XP) to the player and check for level ups.

	Args:
		amount: int - Strength to award (can be 0)
	"""
	if amount <= 0:
		return

	var old_level = player_data["level"]
	player_data["strength"] += amount

	strength_gained.emit(amount, player_data["strength"])

	# Check for level ups (can level multiple times from one battle)
	var new_level = calculate_level_from_strength(player_data["strength"])

	if new_level > old_level:
		player_data["level"] = min(new_level, MAX_LEVEL)
		level_up.emit(player_data["level"])

func calculate_level_from_strength(strength_total: int) -> int:
	"""Calculate player level based on total Strength.

	Args:
		strength_total: int - Total Strength earned

	Returns:
		int - Player level (1-10)
	"""
	for i in range(LEVEL_THRESHOLDS.size() - 1, -1, -1):
		if strength_total >= LEVEL_THRESHOLDS[i]:
			return min(i + 1, MAX_LEVEL)
	return 1

func get_player_level() -> int:
	"""Get current player level (1-10)."""
	return player_data.get("level", 1)

func get_player_strength() -> int:
	"""Get total Strength (XP) earned."""
	return player_data.get("strength", 0)

func get_strength_to_next_level() -> int:
	"""Get Strength needed to reach next level.

	Returns:
		int - Strength needed, or 0 if max level
	"""
	var current_level = get_player_level()
	if current_level >= MAX_LEVEL:
		return 0

	var current_strength = get_player_strength()
	var next_threshold = LEVEL_THRESHOLDS[current_level]
	return max(0, next_threshold - current_strength)

func get_strength_progress_in_level() -> float:
	"""Get progress through current level as percentage (0.0 to 1.0).

	Returns:
		float - Progress percentage, or 1.0 if max level
	"""
	var current_level = get_player_level()
	if current_level >= MAX_LEVEL:
		return 1.0

	var current_strength = get_player_strength()
	var current_threshold = LEVEL_THRESHOLDS[current_level - 1]
	var next_threshold = LEVEL_THRESHOLDS[current_level]
	var strength_in_level = current_strength - current_threshold
	var strength_needed = next_threshold - current_threshold

	return clamp(float(strength_in_level) / float(strength_needed), 0.0, 1.0)

# ============================================================================
# BATTLE COMPLETION TRACKING
# ============================================================================

func record_story_battle_completion(battle_id: String, strength_earned: int):
	"""Record completion of a story battle with Strength earned.

	Args:
		battle_id: String - Unique battle identifier
		strength_earned: int - Strength earned this run
	"""
	if battle_id == "":
		return

	if not player_data.has("completed_story_battles"):
		player_data["completed_story_battles"] = {}

	var previous_best = player_data["completed_story_battles"].get(battle_id, 0)
	player_data["completed_story_battles"][battle_id] = max(previous_best, strength_earned)

func get_story_battle_best_strength(battle_id: String) -> int:
	"""Get the best Strength score for a story battle.

	Args:
		battle_id: String - Unique battle identifier

	Returns:
		int - Best Strength earned, or 0 if never completed
	"""
	if not player_data.has("completed_story_battles"):
		return 0
	return player_data["completed_story_battles"].get(battle_id, 0)

func calculate_battle_strength_improvement(battle_id: String, current_strength: int) -> int:
	"""Calculate Strength to award for story battle replay.

	Players can only earn Strength they haven't earned before.

	Args:
		battle_id: String - Unique battle identifier
		current_strength: int - Strength earned this run

	Returns:
		int - Strength to actually award (improvement only)
	"""
	var previous_best = get_story_battle_best_strength(battle_id)
	return max(0, current_strength - previous_best)

func get_player_name() -> String:
	return player_data.get("name", "")

func get_player_hp() -> int:
	return player_data.get("hp", 100)

func get_player_max_hp() -> int:
	return player_data.get("max_hp", 100)

func is_tutorial_completed() -> bool:
	return player_data.get("tutorial_completed", false)

# ===== RHYTHM GAME HELPERS =====
func get_timing_offset() -> float:
	# Convert milliseconds to seconds
	return get_setting("rhythm_timing_offset", 0) / 1000.0

func get_hit_window_multiplier() -> float:
	# Based on difficulty setting and groove stat
	var base_multiplier = 1.0
	var difficulty = get_setting("difficulty", "normal")
	
	match difficulty:
		"easy":
			base_multiplier = 1.5
		"normal":
			base_multiplier = 1.0
		"hard":
			base_multiplier = 0.7
	
	# Groove stat provides additional leniency
	var groove_bonus = player_data.get("groove", 10) * 0.02  # 2% per groove point
	return base_multiplier + groove_bonus

func calculate_health_loss(base_damage: int) -> int:
	# Strength reduces health loss
	var strength = player_data.get("strength", 10)
	var reduction = strength * 0.1  # 10% reduction per strength point
	return max(1, int(base_damage * (1.0 - reduction)))

func create_fps_display():
	# Create a CanvasLayer to overlay on top of everything
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer so it's always on top
	add_child(canvas_layer)
	
	# Create a container for the background and border
	var panel = PanelContainer.new()
	panel.position = Vector2(10, 10)  # Top-left corner
	
	# Create StyleBox for black background with white border
	var style = StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_content_margin_all(15)
	panel.add_theme_stylebox_override("panel", style)
	
	canvas_layer.add_child(panel)
	
	# Create the FPS label
	fps_label = Label.new()
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_font_size_override("font_size", 30)  # Set font size to 18px
	fps_label.text = "FPS: 60"
	panel.add_child(fps_label)
	
	panel.visible = get_setting("show_fps", false)

func _process(_delta):
	if fps_label and fps_label.visible:
		fps_label.text = "FPS: " + str(int(Engine.get_frames_per_second()))

# ===== AUDIO SETTINGS =====
func apply_audio_settings():
	# Apply volume settings to AudioServer
	var master_vol = get_setting("master_volume", 100) / 100.0
	var music_vol = get_setting("music_volume", 100) / 100.0  
	var sound_vol = get_setting("sound_volume", 100) / 100.0
	
	# Convert to decibels (AudioServer uses dB, not linear values)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_vol))
	if AudioServer.get_bus_index("Music") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(music_vol))
	if AudioServer.get_bus_index("SFX") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(sound_vol))
	
	print("Audio settings applied - Master: ", master_vol, " Music: ", music_vol, " SFX: ", sound_vol)

# ===== DISPLAY SETTINGS =====
func apply_display_settings():
	# Apply fullscreen setting
	var is_fullscreen = get_setting("fullscreen", false)
	if is_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	# Apply FPS display setting
	var show_fps = get_setting("show_fps", false)
	if fps_label and fps_label.get_parent():
		fps_label.get_parent().visible = show_fps  # Show/hide the panel
	
	if show_fps:
		Engine.max_fps = 0  # Unlimited FPS
	else:
		Engine.max_fps = 60  # Cap at 60 FPS
	
	print("Display settings applied - Fullscreen: ", is_fullscreen, " Show FPS: ", show_fps)

# ===== SETTINGS MANAGEMENT =====
func get_setting(key: String, default_value = null):
	return settings.get(key, default_value)

func set_setting(key: String, value):
	settings[key] = value
	save_settings()
	
	# Apply settings immediately when changed
	if key in ["master_volume", "music_volume", "sound_volume"]:
		apply_audio_settings()
	elif key in ["fullscreen", "show_fps"]:
		apply_display_settings()

func save_settings():
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings))
		file.close()
		print("Settings saved: ", settings)
	else:
		print("Failed to save settings")

func load_settings():
	if FileAccess.file_exists(SETTINGS_FILE):
		var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				var loaded_settings = json.data
				if typeof(loaded_settings) == TYPE_DICTIONARY:
					# Merge loaded settings with defaults
					for key in loaded_settings:
						settings[key] = loaded_settings[key]
					print("Settings loaded: ", settings)
				else:
					print("Invalid settings file format")
			else:
				print("Failed to parse settings JSON")
		else:
			print("Failed to open settings file")
	else:
		print("No settings file found, using defaults")

# ===== GAME SAVE/LOAD =====
func save_to_slot(slot: int) -> bool:
	var dir = DirAccess.open("user://")
	if dir == null:
		return false
	if dir and not dir.dir_exists("saves"):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	
	var data = {
		"player": player_data,
		"version": version,
		"time": Time.get_datetime_string_from_system()
	}
	
	var file = FileAccess.open("%s/slot_%d.save" % [SAVE_DIR, slot], FileAccess.WRITE)
	if file == null:
		return false
	
	file.store_string(JSON.stringify(data))
	file.close()
	return true

func load_from_slot(slot: int) -> bool:
	var save_path = "%s/slot_%d.save" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(save_path):
		return false
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		return false
	
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false
	
	player_data = data.get("player", {
		"name": "",
		"favorite_thing": "",
		"selected_character": "",
		"hp": 100,
		"max_hp": 100,
		"strength": 10,
		"groove": 10,
		"xp": 0,
		"level": 1,
		"inventory": [],
		"position": Vector2.ZERO,
		"current_scene": "",
		"tutorial_completed": false
	})
	version = data.get("version", "0.1.0")
	return true

func get_save_info(slot: int) -> Dictionary:
	var save_path = "%s/slot_%d.save" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(save_path):
		return {"exists": false}
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {"exists": false}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result == OK:
		var data = json.data
		if typeof(data) == TYPE_DICTIONARY:
			return {
				"exists": true,
				"time": data.get("time", "Unknown"),
				"version": data.get("version", "Unknown"),
				"player_name": data.get("player", {}).get("name", "Unknown"),
				"level": data.get("player", {}).get("level", 1)
			}
	
	return {"exists": false}

# ===== SCENE MANAGEMENT =====
func change_scene(scene_path: String):
	player_data["current_scene"] = scene_path
	emit_signal("scene_changed", scene_path)
	get_tree().change_scene_to_file(scene_path)
