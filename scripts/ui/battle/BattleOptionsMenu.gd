extends Control
signal closed

@onready var master_volume_slider: HSlider = $GameOptionsContainer/MasterVolumeBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $GameOptionsContainer/MusicVolumeBox/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $GameOptionsContainer/SoundVolumeBox/SoundVolumeSlider
@onready var rhythm_timing_slider: HSlider = $GameOptionsContainer/RhythmTiming/RhythmTimingSlider
@onready var rhythm_timing_label: Label = $GameOptionsContainer/RhythmTiming/RhythmTimingValue
@onready var difficulty_slider: HSlider = $GameOptionsContainer/DifficultyBox/DifficultySlider
@onready var difficulty_value_label: Label = $GameOptionsContainer/DifficultyBox/DifficultyValueLabel
@onready var fullscreen_checkbox: CheckBox = $GameOptionsContainer/FullScreenContainer/FullScreenCheckbox
@onready var framerate_checkbox: CheckBox = $GameOptionsContainer/FramerateContainer/FramerateCheckbox
@onready var close_button: Button = $GameOptionsContainer/ButtonsContainer/CloseButton
@onready var exit_button: Button = $GameOptionsContainer/ButtonsContainer/ExitButton

# Dialog and overlay
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var dialog_overlay: ColorRect = $DialogOverlay

# Audio players
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var cancel_sound: AudioStreamPlayer = $CancelSound
@onready var exit_confirm_sound: AudioStreamPlayer = $GameOptionsContainer/ButtonsContainer/ExitConfirmSound

func _ready():
	# Connect volume sliders
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
		master_volume_slider.mouse_entered.connect(func(): button_hover_sound.play())
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
		music_volume_slider.mouse_entered.connect(func(): button_hover_sound.play())
	if sound_volume_slider:
		sound_volume_slider.value_changed.connect(_on_sound_volume_changed)
		sound_volume_slider.mouse_entered.connect(func(): button_hover_sound.play())

	# Connect rhythm timing slider
	if rhythm_timing_slider:
		rhythm_timing_slider.value_changed.connect(_on_rhythm_timing_changed)
		rhythm_timing_slider.mouse_entered.connect(func(): button_hover_sound.play())

	# Connect difficulty slider
	if difficulty_slider:
		difficulty_slider.value_changed.connect(_on_difficulty_changed)
		difficulty_slider.mouse_entered.connect(func(): button_hover_sound.play())

	# Connect checkboxes
	if fullscreen_checkbox:
		fullscreen_checkbox.mouse_entered.connect(func(): button_hover_sound.play())
	if framerate_checkbox:
		framerate_checkbox.mouse_entered.connect(func(): button_hover_sound.play())

	# Connect buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		close_button.mouse_entered.connect(func(): button_hover_sound.play())
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		exit_button.mouse_entered.connect(func(): button_hover_sound.play())

	# Connect dialog
	if exit_dialog:
		exit_dialog.confirmed.connect(_on_exit_confirmed)
		exit_dialog.canceled.connect(_on_exit_canceled)
		exit_dialog.hide()

	# Initialize overlay
	if dialog_overlay:
		dialog_overlay.hide()

	# Start hidden and make sure tree is not paused
	hide()

	# Load saved settings
	load_settings()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Don't toggle menu if dialog is open
		if exit_dialog and exit_dialog.visible:
			return
		toggle_menu()
		get_viewport().set_input_as_handled()

# Volume control functions
func _on_master_volume_changed(value):
	GameManager.set_setting("master_volume", value)

func _on_music_volume_changed(value):
	GameManager.set_setting("music_volume", value)

func _on_sound_volume_changed(value):
	GameManager.set_setting("sound_volume", value)

func _on_rhythm_timing_changed(value):
	GameManager.set_setting("rhythm_timing_offset", value)
	if rhythm_timing_label:
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
	print(">>> Fullscreen toggled: ", checked)
	GameManager.set_setting("fullscreen", checked)

func _on_framerate_toggled(checked):
	print(">>> Framerate toggled: ", checked)
	GameManager.set_setting("show_fps", checked)

func toggle_menu():
	if visible:
		hide_menu()
	else:
		show_menu()

func show_menu():
	show()
	get_tree().paused = true

func hide_menu():
	hide()
	get_tree().paused = false
	emit_signal("closed")

func _on_close_pressed():
	# Save and close the menu
	success_sound.play()
	GameManager.save_settings()
	hide_menu()

func _on_exit_pressed():
	# Show confirmation dialog
	exit_confirm_sound.play()
	_show_dialog_with_overlay()

func _on_exit_confirmed():
	# Return to title screen after confirmation
	_hide_dialog_overlay()
	cancel_sound.play()  # Hurt sound for quitting/giving up
	get_tree().paused = false

	# Signal battle to end gracefully (not as a fail)
	if BattleManager:
		BattleManager.player_quit_to_title = true

	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func _on_exit_canceled():
	# Just hide the dialog
	_hide_dialog_overlay()
	success_sound.play()  # Success sound for staying in battle

func _show_dialog_with_overlay():
	if dialog_overlay:
		dialog_overlay.show()
	if exit_dialog:
		exit_dialog.popup_centered()

func _hide_dialog_overlay():
	if dialog_overlay:
		dialog_overlay.hide()
	if exit_dialog:
		exit_dialog.hide()

func load_settings():
	if master_volume_slider:
		master_volume_slider.value = GameManager.get_setting("master_volume", 100)
	if music_volume_slider:
		music_volume_slider.value = GameManager.get_setting("music_volume", 100)
	if sound_volume_slider:
		sound_volume_slider.value = GameManager.get_setting("sound_volume", 100)
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
