extends Control
signal closed

@onready var master_volume_slider: HSlider = $OptionsContainer/MasterVolumeBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $OptionsContainer/MusicVolumeBox/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $OptionsContainer/SoundVolumeBox/SoundVolumeSlider
@onready var rhythm_timing_slider: HSlider = $OptionsContainer/RhythmTiming/RhythmTimingSlider
@onready var rhythm_timing_label: Label = $OptionsContainer/RhythmTiming/RhythmTimingValue
@onready var difficulty_slider: HSlider = $OptionsContainer/DifficultyBox/DifficultySlider
@onready var difficulty_value_label: Label = $OptionsContainer/DifficultyBox/DifficultyValueLabel
@onready var fullscreen_checkbox: CheckBox = $OptionsContainer/FullScreenContainer/FullScreenCheckbox
@onready var framerate_checkbox: CheckBox = $OptionsContainer/FramerateContainer/FramerateCheckbox
@onready var close_button: Button = $OptionsContainer/CloseButton
@onready var reset_button: Button = $OptionsContainer/ResetButton

# Audio players
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound

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

	# Connect close button
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		close_button.mouse_entered.connect(_on_button_hover)

	# Connect reset button
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
		reset_button.mouse_entered.connect(_on_button_hover)

	# Load saved settings
	load_settings()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()

# Volume control functions
func _on_master_volume_changed(value):
	GameManager.set_setting("master_volume", value)

func _on_music_volume_changed(value):
	GameManager.set_setting("music_volume", value)

func _on_sound_volume_changed(value):
	GameManager.set_setting("sound_volume", value)

func _on_rhythm_timing_changed(value):
	GameManager.set_setting("rhythm_timing_offset", value)
	rhythm_timing_label.text = str(int(value)) + " ms"

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
	GameManager.set_setting("fullscreen", checked)

func _on_framerate_toggled(checked):
	GameManager.set_setting("show_fps", checked)

func _on_close_pressed():
	success_sound.play()
	# Wait for sound to complete before closing
	await get_tree().create_timer(0.3).timeout
	emit_signal("closed")

func _on_reset_pressed():
	"""Reset all settings to default values."""
	success_sound.play()
	# Reset all settings to defaults
	GameManager.set_setting("master_volume", 85)
	GameManager.set_setting("music_volume", 75)
	GameManager.set_setting("sound_volume", 65)
	GameManager.set_setting("rhythm_timing_offset", 0)
	GameManager.set_setting("difficulty", "gymbro")
	GameManager.set_setting("fullscreen", false)
	GameManager.set_setting("show_fps", false)
	# Reload UI to reflect defaults
	load_settings()
	GameManager.save_settings()

func load_settings():
	if master_volume_slider:
		master_volume_slider.value = GameManager.get_setting("master_volume", 85)
	if music_volume_slider:
		music_volume_slider.value = GameManager.get_setting("music_volume", 75)
	if sound_volume_slider:
		sound_volume_slider.value = GameManager.get_setting("sound_volume", 65)
	if rhythm_timing_slider:
		var timing_offset = GameManager.get_setting("rhythm_timing_offset", 0)
		rhythm_timing_slider.value = timing_offset
		if rhythm_timing_label:
			rhythm_timing_label.text = str(int(timing_offset)) + " ms"
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

func _on_button_hover():
	"""Play hover sound when mouse enters button."""
	if button_hover_sound:
		button_hover_sound.play()
