extends Control
signal closed
signal exit_to_title

@onready var master_volume_slider: HSlider = $GameOptionsContainer/MasterVolumeBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $GameOptionsContainer/MusicVolumeBox/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $GameOptionsContainer/SoundVolumeBox/SoundVolumeSlider
@onready var rhythm_timing_slider: HSlider = $GameOptionsContainer/RhythmTiming/RhythmTimingSlider
@onready var fullscreen_checkbox: CheckBox = $GameOptionsContainer/FullScreenContainer/FullScreenCheckbox
@onready var framerate_checkbox: CheckBox = $GameOptionsContainer/FramerateContainer/FramerateCheckbox
@onready var save_btn: Button = $GameOptionsContainer/ButtonsContainer/SaveButton
@onready var exit_btn: Button = $GameOptionsContainer/ButtonsContainer/ExitButton

# Audio nodes
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var button_enter_sound: AudioStreamPlayer = $ButtonEnterSound
@onready var exit_confirm_sound: AudioStreamPlayer = $GameOptionsContainer/ButtonsContainer/ExitConfirmSound

# Exit confirmation dialog
var exit_dialog: ConfirmationDialog = null
var dialog_overlay: ColorRect = null

func _ready():
	# Create exit confirmation dialog
	create_exit_dialog()

	# Connect volume sliders
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if music_volume_slider:
		music_volume_slider.value_changed.connect(_on_music_volume_changed)
	if sound_volume_slider:
		sound_volume_slider.value_changed.connect(_on_sound_volume_changed)
	if rhythm_timing_slider:
		rhythm_timing_slider.value_changed.connect(_on_rhythm_timing_changed)

	# Connect buttons
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
		save_btn.mouse_entered.connect(_on_button_hover)
	if exit_btn:
		exit_btn.pressed.connect(_on_exit_pressed)
		exit_btn.mouse_entered.connect(_on_button_hover)

	# Load saved settings
	load_settings()

func create_exit_dialog():
	# Create overlay
	dialog_overlay = ColorRect.new()
	dialog_overlay.color = Color(0, 0, 0, 0.7)
	dialog_overlay.size = Vector2(1920, 1080)
	dialog_overlay.position = Vector2(0, 0)
	dialog_overlay.z_index = 100
	dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_overlay.hide()
	add_child(dialog_overlay)

	# Create dialog
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.dialog_text = "Exit to title screen? Any unsaved progress will be lost."
	exit_dialog.title = "Exit Game"
	exit_dialog.z_index = 101
	exit_dialog.hide()
	add_child(exit_dialog)

	# Connect dialog signals
	exit_dialog.confirmed.connect(_on_exit_confirmed)
	exit_dialog.canceled.connect(_on_exit_canceled)

	# Connect button sounds after dialog is created
	call_deferred("_connect_dialog_sounds")

func _connect_dialog_sounds():
	if exit_dialog:
		var cancel_btn = exit_dialog.get_cancel_button()
		var ok_btn = exit_dialog.get_ok_button()

		if cancel_btn and not cancel_btn.mouse_entered.is_connected(_on_button_hover):
			cancel_btn.mouse_entered.connect(_on_button_hover)
			cancel_btn.pressed.connect(_on_button_enter)

		if ok_btn and not ok_btn.mouse_entered.is_connected(_on_button_hover):
			ok_btn.mouse_entered.connect(_on_button_hover)
			ok_btn.pressed.connect(_on_button_enter)

func _unhandled_input(event):
	if event.is_action_pressed("options"):
		if exit_dialog and exit_dialog.visible:
			return
		_on_save_pressed()

# Volume control functions
func _on_master_volume_changed(value):
	GameManager.set_setting("master_volume", value)

func _on_music_volume_changed(value):
	GameManager.set_setting("music_volume", value)

func _on_sound_volume_changed(value):
	GameManager.set_setting("sound_volume", value)

func _on_rhythm_timing_changed(value):
	# Slider value directly represents timing offset (-200 to +200)
	GameManager.set_setting("rhythm_timing_offset", value)

func _on_fullscreen_toggled(checked):
	GameManager.set_setting("fullscreen", checked)

func _on_framerate_toggled(checked):
	GameManager.set_setting("show_fps", checked)

func _on_save_pressed():
	if button_enter_sound:
		button_enter_sound.play()
	emit_signal("closed")

func _on_exit_pressed():
	if exit_confirm_sound:
		exit_confirm_sound.play()
	show_exit_dialog()

func show_exit_dialog():
	if dialog_overlay:
		dialog_overlay.show()
	if exit_dialog:
		exit_dialog.popup_centered()

func _on_exit_confirmed():
	hide_exit_dialog()
	emit_signal("exit_to_title")

func _on_exit_canceled():
	hide_exit_dialog()

func hide_exit_dialog():
	if dialog_overlay:
		dialog_overlay.hide()
	if exit_dialog:
		exit_dialog.hide()

func _on_button_hover():
	if button_hover_sound:
		button_hover_sound.play()

func _on_button_enter():
	if button_enter_sound:
		button_enter_sound.play()

func load_settings():
	if master_volume_slider:
		master_volume_slider.value = GameManager.get_setting("master_volume", 100)
	if music_volume_slider:
		music_volume_slider.value = GameManager.get_setting("music_volume", 100)
	if sound_volume_slider:
		sound_volume_slider.value = GameManager.get_setting("sound_volume", 100)
	if rhythm_timing_slider:
		# Slider value directly represents timing offset (-200 to +200)
		rhythm_timing_slider.value = GameManager.get_setting("rhythm_timing_offset", 0)
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = GameManager.get_setting("fullscreen", false)
	if framerate_checkbox:
		framerate_checkbox.button_pressed = GameManager.get_setting("show_fps", false)
