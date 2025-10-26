extends Control
signal closed

@onready var master_volume_slider: HSlider = $OptionsContainer/MasterVolumeBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $OptionsContainer/MusicVolumeBox/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $OptionsContainer/SoundVolumeBox/SoundVolumeSlider
@onready var rhythm_timing_slider: HSlider = $OptionsContainer/RhythmTiming/RhythmTimingSlider
@onready var difficulty_slider: HSlider = $OptionsContainer/DifficultyBox/DifficultySlider
@onready var difficulty_value_label: Label = $OptionsContainer/DifficultyBox/DifficultyValueLabel
@onready var fullscreen_checkbox: CheckBox = $OptionsContainer/FullScreenContainer/FullScreenCheckbox
@onready var framerate_checkbox: CheckBox = $OptionsContainer/FramerateContainer/FramerateCheckbox
@onready var save_btn: Button = $OptionsContainer/SaveButton

func _ready():
	# Connect volume sliders
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sound_volume_slider:
		sound_volume_slider.value_changed.connect(_on_sound_volume_changed)

	# Connect rhythm timing slider
	if rhythm_timing_slider:
		rhythm_timing_slider.value_changed.connect(_on_rhythm_timing_changed)

	# Connect difficulty slider
	if difficulty_slider:
		difficulty_slider.value_changed.connect(_on_difficulty_changed)

	# Checkboxes are already connected in the editor, so we don't connect them here

	# Connect save button
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)

	# Load saved settings
	load_settings()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_save_pressed()

# Volume control functions
func _on_master_volume_changed(value):
	GameManager.set_setting("master_volume", value)

func _on_music_volume_changed(value):
	GameManager.set_setting("music_volume", value)

func _on_sound_volume_changed(value):
	GameManager.set_setting("sound_volume", value)

func _on_rhythm_timing_changed(value):
	# Convert slider value (0-2000) to timing offset (-1000 to +1000)
	var timing_offset = value - 1000
	GameManager.set_setting("rhythm_timing_offset", timing_offset)

func _on_difficulty_changed(value):
	# Convert slider value (0-4) to difficulty string
	var difficulty_str = ""
	var display_text = ""
	match int(value):
		0:
			difficulty_str = "wimpy"
			display_text = "Wimpy"
		1:
			difficulty_str = "casual"
			display_text = "Casual"
		2:
			difficulty_str = "gymbro"
			display_text = "Gymbro"
		3:
			difficulty_str = "meathead"
			display_text = "Meathead"
		4:
			difficulty_str = "gigachad"
			display_text = "Gigachad"

	GameManager.set_setting("difficulty", difficulty_str)
	BattleManager.set_difficulty(difficulty_str)
	if difficulty_value_label:
		difficulty_value_label.text = display_text

func _on_fullscreen_toggled(checked):
	print(">>> Fullscreen toggled: ", checked)
	GameManager.set_setting("fullscreen", checked)

func _on_framerate_toggled(checked):
	print(">>> Framerate toggled: ", checked)
	GameManager.set_setting("show_fps", checked)

func _on_save_pressed():
	emit_signal("closed")
	# DON'T set visible = false here! Let the parent handle cleanup

func load_settings():
	if master_volume_slider:
		master_volume_slider.value = GameManager.get_setting("master_volume", 100)
	if music_volume_slider:
		music_volume_slider.value = GameManager.get_setting("music_volume", 100)
	if sound_volume_slider:
		sound_volume_slider.value = GameManager.get_setting("sound_volume", 100)
	if rhythm_timing_slider:
		# Convert timing offset (-1000 to +1000) to slider value (0 to 2000)
		var timing_offset = GameManager.get_setting("rhythm_timing_offset", 0)
		rhythm_timing_slider.value = timing_offset + 1000
	if difficulty_slider:
		# Convert difficulty string to slider value (0-4)
		var difficulty = GameManager.get_setting("difficulty", "gymbro")

		# Handle legacy difficulty names (old 3-level system)
		if difficulty == "easy":
			difficulty = "wimpy"
			GameManager.set_setting("difficulty", difficulty)
		elif difficulty == "normal":
			difficulty = "gymbro"
			GameManager.set_setting("difficulty", difficulty)
		elif difficulty == "hard":
			difficulty = "meathead"
			GameManager.set_setting("difficulty", difficulty)

		var slider_value = 2
		var display_text = "Gymbro"
		match difficulty:
			"wimpy":
				slider_value = 0
				display_text = "Wimpy"
			"casual":
				slider_value = 1
				display_text = "Casual"
			"gymbro":
				slider_value = 2
				display_text = "Gymbro"
			"meathead":
				slider_value = 3
				display_text = "Meathead"
			"gigachad":
				slider_value = 4
				display_text = "Gigachad"
		difficulty_slider.value = slider_value
		if difficulty_value_label:
			difficulty_value_label.text = display_text
		# Sync with BattleManager
		BattleManager.set_difficulty(difficulty)
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = GameManager.get_setting("fullscreen", false)
	if framerate_checkbox:
		framerate_checkbox.button_pressed = GameManager.get_setting("show_fps", false)
