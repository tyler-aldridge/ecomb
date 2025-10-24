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
@onready var exit_confirm_sound: AudioStreamPlayer = $ExitConfirmSound
@onready var cancel_sound: AudioStreamPlayer = $CancelSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound

# Exit confirmation dialog (matches MainTitle pattern)
var exit_dialog: ConfirmationDialog = null
var dialog_overlay: ColorRect = null

func _ready():
	# Create exit confirmation dialog (matches MainTitle's quit_dialog)
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
	# Create overlay (matches MainTitle's dialog_overlay)
	dialog_overlay = ColorRect.new()
	dialog_overlay.color = Color(0, 0, 0, 0.7)
	dialog_overlay.size = Vector2(1920, 1080)
	dialog_overlay.position = Vector2(0, 0)
	dialog_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog_overlay.hide()
	add_child(dialog_overlay)

	# Create dialog (matches MainTitle's quit_dialog)
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.dialog_text = "Exit to title screen? Any unsaved progress will be lost."
	exit_dialog.title = "Exit Game"
	exit_dialog.z_index = 101
	exit_dialog.hide()
	add_child(exit_dialog)

	# Connect dialog signals
	exit_dialog.confirmed.connect(_on_exit_confirmed)
	exit_dialog.canceled.connect(_on_exit_canceled)

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
	_show_dialog_with_overlay(exit_dialog)

# --- Dialog Management (matches MainTitle pattern exactly) ---
func _show_dialog_with_overlay(dialog: ConfirmationDialog):
	dialog_overlay.show()
	dialog.popup_centered()

	# Connect sounds for this specific dialog after it's shown
	call_deferred("_connect_dialog_sounds", dialog)

func _connect_dialog_sounds(dialog: ConfirmationDialog):
	var cancel_btn = dialog.get_cancel_button()
	var ok_btn = dialog.get_ok_button()

	if cancel_btn:
		cancel_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		cancel_btn.focus_mode = Control.FOCUS_ALL
		if not cancel_btn.mouse_entered.is_connected(_on_dialog_button_hover):
			cancel_btn.mouse_entered.connect(_on_dialog_button_hover)

	if ok_btn:
		ok_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		ok_btn.focus_mode = Control.FOCUS_ALL
		if not ok_btn.mouse_entered.is_connected(_on_dialog_button_hover):
			ok_btn.mouse_entered.connect(_on_dialog_button_hover)

	# Connect click sounds for exit dialog
	if dialog == exit_dialog:
		if cancel_btn and not cancel_btn.pressed.is_connected(_on_exit_dialog_cancel_pressed):
			cancel_btn.pressed.connect(_on_exit_dialog_cancel_pressed)
		if ok_btn and not ok_btn.pressed.is_connected(_on_exit_dialog_ok_pressed):
			ok_btn.pressed.connect(_on_exit_dialog_ok_pressed)

func _on_dialog_button_hover():
	if button_hover_sound:
		button_hover_sound.play()

# Exit dialog sounds
func _on_exit_dialog_cancel_pressed():
	if cancel_sound:
		cancel_sound.play()
	_hide_dialog_overlay()

func _on_exit_dialog_ok_pressed():
	if success_sound:
		success_sound.play()

func _hide_dialog_overlay():
	if dialog_overlay:
		dialog_overlay.hide()

func _on_exit_confirmed():
	_hide_dialog_overlay()
	emit_signal("exit_to_title")

func _on_exit_canceled():
	_hide_dialog_overlay()

func _on_button_hover():
	if button_hover_sound:
		button_hover_sound.play()

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
