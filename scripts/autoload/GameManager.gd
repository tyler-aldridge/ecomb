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
	"strength": 10,  # Affects health loss rate
	"groove": 10,    # Timing leniency modifier
	"xp": 0,
	"level": 1,
	"inventory": [],
	"position": Vector2.ZERO,
	"current_scene": "",
	"tutorial_completed": false
}

# Settings storage - enhanced with rhythm settings
var settings = {
	"master_volume": 100,
	"music_volume": 100,
	"sound_volume": 100,
	"rhythm_timing_offset": 0,  # For audio latency compensation
	"fullscreen": false,
	"show_fps": false,
	"difficulty": "normal"  # easy, normal, hard
}

# File paths
const SETTINGS_FILE = "user://settings.save"
const SAVE_DIR = "user://saves"

# FPS Display
var fps_label: Label = null
var last_fps: int = 0

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

func add_xp(amount: int):
	player_data["xp"] += amount
	check_level_up()

func check_level_up():
	var xp_needed = player_data["level"] * 100  # Simple leveling formula
	if player_data["xp"] >= xp_needed:
		player_data["level"] += 1
		player_data["xp"] -= xp_needed
		level_up_stats()
		print("Level up! Now level ", player_data["level"])

func level_up_stats():
	# Increase stats on level up
	player_data["max_hp"] += 10
	player_data["hp"] = player_data["max_hp"]  # Full heal on level up
	player_data["strength"] += 2
	player_data["groove"] += 1

func get_player_name() -> String:
	return player_data.get("name", "")

func get_player_hp() -> int:
	return player_data.get("hp", 100)

func get_player_max_hp() -> int:
	return player_data.get("max_hp", 100)

func get_player_strength() -> int:
	return player_data.get("strength", 10)

func get_player_groove() -> int:
	return player_data.get("groove", 10)

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
		var current_fps = int(Engine.get_frames_per_second())
		if current_fps != last_fps:
			fps_label.text = "FPS: " + str(current_fps)
			last_fps = current_fps

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
