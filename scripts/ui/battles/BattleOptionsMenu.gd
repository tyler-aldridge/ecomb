extends Control
signal closed

@onready var master_volume_slider: HSlider = $GameOptionsContainer/MasterVolumeBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $GameOptionsContainer/MusicVolumeBox/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $GameOptionsContainer/SoundVolumeBox/SoundVolumeSlider
@onready var text_volume_slider: HSlider = $GameOptionsContainer/TextVolumeBox/TextVolumeSlider
@onready var difficulty_slider: HSlider = $GameOptionsContainer/DifficultyBox/DifficultySlider
@onready var difficulty_value_label: Label = $GameOptionsContainer/DifficultyBox/DifficultyValueLabel
@onready var fullscreen_checkbox: CheckBox = $GameOptionsContainer/CheckboxesContainer/FullScreenContainer/FullScreenCheckbox
@onready var framerate_checkbox: CheckBox = $GameOptionsContainer/CheckboxesContainer/FramerateContainer/FramerateCheckbox
@onready var close_button: Button = $GameOptionsContainer/ButtonsContainer/CloseButton
@onready var exit_button: Button = $GameOptionsContainer/ButtonsContainer/ExitButton
@onready var reset_button: Button = $GameOptionsContainer/ButtonsContainer/ResetButton

# New buttons (will be created programmatically)
var restart_button: Button
var recalibrate_button: Button
var battle_buttons_container: HBoxContainer

# Dialogs and overlays
@onready var exit_dialog: ConfirmationDialog = $ExitDialog
@onready var dialog_overlay: ColorRect = $DialogOverlay
var restart_dialog: ConfirmationDialog
var recalibrate_dialog: ConfirmationDialog

# Audio players
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var cancel_sound: AudioStreamPlayer = $CancelSound
@onready var exit_confirm_sound: AudioStreamPlayer = $GameOptionsContainer/ButtonsContainer/ExitConfirmSound

# Track current battle scene path for recalibrate flow
var current_battle_scene_path: String = ""

func _ready():
	# Connect volume sliders
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sound_volume_slider:
		sound_volume_slider.value_changed.connect(_on_sound_volume_changed)
	if text_volume_slider:
		text_volume_slider.value_changed.connect(_on_text_volume_changed)

	# Connect difficulty slider
	if difficulty_slider:
		difficulty_slider.value_changed.connect(_on_difficulty_changed)

	# Connect buttons
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		close_button.mouse_entered.connect(_on_button_hover)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		exit_button.mouse_entered.connect(_on_button_hover)
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
		reset_button.mouse_entered.connect(_on_button_hover)

	# Connect dialog
	if exit_dialog:
		exit_dialog.confirmed.connect(_on_exit_confirmed)
		exit_dialog.canceled.connect(_on_exit_canceled)
		exit_dialog.hide()

	# Initialize overlay
	if dialog_overlay:
		dialog_overlay.hide()

	# Create battle action buttons row
	_create_battle_buttons()

	# Create confirmation dialogs
	_create_restart_dialog()
	_create_recalibrate_dialog()

	# Store current battle scene path
	current_battle_scene_path = get_tree().current_scene.scene_file_path

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

func _on_text_volume_changed(value):
	GameManager.set_setting("text_volume", value)

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

func toggle_menu():
	if visible:
		hide_menu()
	else:
		show_menu()

func show_menu():
	show()
	get_tree().paused = true

	# Pause the music/Conductor to prevent desync
	var conductor = get_tree().get_first_node_in_group("conductor")
	if conductor and conductor is AudioStreamPlayer:
		conductor.stream_paused = true

func hide_menu():
	# Unpause audio FIRST, then tree, so both resume on same physics tick
	var conductor = get_tree().get_first_node_in_group("conductor")
	if conductor and conductor is AudioStreamPlayer:
		conductor.stream_paused = false

	hide()
	get_tree().paused = false
	emit_signal("closed")

func _on_close_pressed():
	# Save and close the menu
	success_sound.play()
	GameManager.save_settings()
	hide_menu()

func _on_reset_pressed():
	"""Reset all settings to default values."""
	success_sound.play()
	# Reset all settings to defaults
	GameManager.set_setting("master_volume", 85)
	GameManager.set_setting("music_volume", 75)
	GameManager.set_setting("sound_volume", 65)
	GameManager.set_setting("text_volume", 55)
	GameManager.set_setting("difficulty", "gymbro")
	GameManager.set_setting("fullscreen", false)
	GameManager.set_setting("show_fps", false)
	# Reload UI to reflect defaults
	load_settings()
	GameManager.save_settings()

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

	get_tree().change_scene_to_file("res://scenes/ui/title/MainTitle.tscn")

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
	if text_volume_slider:
		text_volume_slider.value = GameManager.get_setting("text_volume", 100)
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

# ============================================================================
# BATTLE ACTION BUTTONS (Restart, Recalibrate)
# ============================================================================

func _create_battle_buttons():
	"""Create a second row of buttons for battle-specific actions."""
	# Create container for battle action buttons
	battle_buttons_container = HBoxContainer.new()
	battle_buttons_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	battle_buttons_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	battle_buttons_container.add_theme_constant_override("separation", 50)

	# Get the main VBoxContainer
	var main_container = $GameOptionsContainer
	if not main_container:
		return

	# Add battle buttons container after the first ButtonsContainer
	main_container.add_child(battle_buttons_container)
	main_container.move_child(battle_buttons_container, main_container.get_child_count() - 1)

	# Create Restart Battle button
	restart_button = _create_styled_button("Restart Battle")
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.mouse_entered.connect(_on_button_hover)
	battle_buttons_container.add_child(restart_button)

	# Create Recalibrate button
	recalibrate_button = _create_styled_button("Recalibrate")
	recalibrate_button.pressed.connect(_on_recalibrate_pressed)
	recalibrate_button.mouse_entered.connect(_on_button_hover)
	battle_buttons_container.add_child(recalibrate_button)

func _create_styled_button(button_text: String) -> Button:
	"""Create a button with consistent styling matching existing buttons."""
	var button = Button.new()
	button.text = button_text
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 50)

	# Normal style (white border)
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.BLACK
	normal_style.border_width_left = 3
	normal_style.border_width_top = 3
	normal_style.border_width_right = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color.WHITE
	normal_style.content_margin_left = 50
	normal_style.content_margin_right = 50
	normal_style.content_margin_top = 25
	normal_style.content_margin_bottom = 25
	button.add_theme_stylebox_override("normal", normal_style)

	# Hover style (yellow border)
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color.BLACK
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color.YELLOW
	hover_style.content_margin_left = 50
	hover_style.content_margin_right = 50
	hover_style.content_margin_top = 25
	hover_style.content_margin_bottom = 25
	button.add_theme_stylebox_override("hover", hover_style)

	# Pressed style (yellow border)
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color.BLACK
	pressed_style.border_width_left = 3
	pressed_style.border_width_top = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_bottom = 3
	pressed_style.border_color = Color.YELLOW
	pressed_style.content_margin_left = 50
	pressed_style.content_margin_right = 50
	pressed_style.content_margin_top = 25
	pressed_style.content_margin_bottom = 25
	button.add_theme_stylebox_override("pressed", pressed_style)

	return button

func _create_restart_dialog():
	"""Create confirmation dialog for restarting battle."""
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	restart_dialog.dialog_text = "Are you sure you want to start at square one?"
	restart_dialog.dialog_autowrap = true
	restart_dialog.confirmed.connect(_on_restart_confirmed)
	restart_dialog.canceled.connect(_on_restart_canceled)
	restart_dialog.hide()
	add_child(restart_dialog)

func _create_recalibrate_dialog():
	"""Create confirmation dialog for recalibrating."""
	recalibrate_dialog = ConfirmationDialog.new()
	recalibrate_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	recalibrate_dialog.dialog_text = "Are you sure you want end this battle to recalibrate?"
	recalibrate_dialog.dialog_autowrap = true
	recalibrate_dialog.confirmed.connect(_on_recalibrate_confirmed)
	recalibrate_dialog.canceled.connect(_on_recalibrate_canceled)
	recalibrate_dialog.hide()
	add_child(recalibrate_dialog)

func _on_restart_pressed():
	"""Show restart confirmation dialog."""
	exit_confirm_sound.play()
	_show_restart_dialog()

func _on_restart_confirmed():
	"""Restart the battle after confirmation."""
	_hide_restart_dialog()
	cancel_sound.play()
	get_tree().paused = false

	# Reload current scene (battle)
	get_tree().reload_current_scene()

func _on_restart_canceled():
	"""Cancel restart and return to menu."""
	_hide_restart_dialog()
	success_sound.play()

func _on_recalibrate_pressed():
	"""Show recalibrate confirmation dialog."""
	exit_confirm_sound.play()
	_show_recalibrate_dialog()

func _on_recalibrate_confirmed():
	"""Go to calibrator, then return to battle."""
	_hide_recalibrate_dialog()
	cancel_sound.play()
	get_tree().paused = false

	# Store battle scene path in GameManager for return navigation
	GameManager.set_meta("return_to_battle", current_battle_scene_path)

	# Go to calibrator scene
	get_tree().change_scene_to_file("res://scenes/ui/universal/RhythmCalibration.tscn")

func _on_recalibrate_canceled():
	"""Cancel recalibration and return to menu."""
	_hide_recalibrate_dialog()
	success_sound.play()

func _show_restart_dialog():
	"""Show restart dialog with overlay."""
	if dialog_overlay:
		dialog_overlay.show()
	if restart_dialog:
		restart_dialog.popup_centered()

func _hide_restart_dialog():
	"""Hide restart dialog and overlay."""
	if restart_dialog:
		restart_dialog.hide()
	if dialog_overlay:
		dialog_overlay.hide()

func _show_recalibrate_dialog():
	"""Show recalibrate dialog with overlay."""
	if dialog_overlay:
		dialog_overlay.show()
	if recalibrate_dialog:
		recalibrate_dialog.popup_centered()

func _hide_recalibrate_dialog():
	"""Hide recalibrate dialog and overlay."""
	if recalibrate_dialog:
		recalibrate_dialog.hide()
	if dialog_overlay:
		dialog_overlay.hide()
