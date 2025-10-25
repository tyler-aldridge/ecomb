extends Control
signal closed

@onready var master_volume_slider: HSlider = $OptionsContainer/MasterVolumeBox/MasterVolumeSlider
@onready var music_volume_slider: HSlider = $OptionsContainer/MusicVolumeBox/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $OptionsContainer/SoundVolumeBox/SoundVolumeSlider
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
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = GameManager.get_setting("fullscreen", false)
	if framerate_checkbox:
		framerate_checkbox.button_pressed = GameManager.get_setting("show_fps", false)
