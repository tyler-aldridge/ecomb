extends Control

@onready var fade: ColorRect              = $UI/MainTitleFadeRect
@onready var music: AudioStreamPlayer     = $MainTitleMusic
@onready var hit_timer: Timer             = $UI/HitTimer
@onready var title_anim: AnimationPlayer  = $UI/MainTitleTextAnimation
@onready var button_anim: AnimationPlayer = $UI/MainTitleButtonAnimation

@onready var new_btn      = $UI/NewButton
@onready var load_btn     = $UI/LoadButton
@onready var options_btn  = $UI/OptionsButton
@onready var exit_btn     = $UI/ExitButton

@onready var quit_dialog: ConfirmationDialog   = $Systems/QuitDialog
@onready var delete_dialog: ConfirmationDialog = $Systems/DeleteDialog
@onready var dialog_overlay: ColorRect = $Systems/DialogOverlay

@onready var modal_layer: CanvasLayer = $Systems/ModalLayer
@onready var modal_container: Control = $Systems/ModalLayer/ModalRoot

# Audio node references
@onready var main_title_sound: AudioStreamPlayer = $MainTitleSound
@onready var button_enter_sound: AudioStreamPlayer = $ButtonEnterSound
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var success_sound: AudioStreamPlayer = $SuccessSound
@onready var cancel_sound: AudioStreamPlayer = $CancelSound
@onready var warning_confirm_sound: AudioStreamPlayer = $WarningConfirmSound
@onready var exit_confirm_sound: AudioStreamPlayer = $ExitConfirmSound
@onready var crab_sound: AudioStreamPlayer = $CrabSound
@onready var muscle_man_sound: AudioStreamPlayer = $MuscleManSound

var current_modal: Control = null
var pending_delete_save_id: String = ""

const FADE_DUR := 6.0
const HIT_TIME := 5.0
const BUTTON_DELAY := 1.5

const CHAR_CREATE_SCENE:  PackedScene = preload("res://scenes/ui/title/CharacterCreation.tscn")
const LOAD_MENU_SCENE:   PackedScene = preload("res://scenes/ui/title/LoadMenu.tscn")
const OPTIONS_MENU_SCENE: PackedScene = preload("res://scenes/ui/title/TitleOptionsMenu.tscn")

func _ready():
	# Add the title scene to a group so Muscle Man can find it
	add_to_group("title_scene")
	
	# Initialize all dialogs as hidden
	quit_dialog.hide()
	delete_dialog.hide()
	dialog_overlay.hide()
	
	# Music setup
	if not music.is_in_group("music"): 
		music.add_to_group("music")
	music.volume_db = 0.0
	music.play()
	
	# Fade in
	fade.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, FADE_DUR)
	tween.tween_callback(_hide_fade_overlay)
	
	# Title animation
	hit_timer.wait_time = HIT_TIME
	hit_timer.timeout.connect(_on_hit_timer_timeout)
	hit_timer.start()
	
	# Connect all buttons
	new_btn.pressed.connect(_on_new_button_pressed)
	load_btn.pressed.connect(_on_load_button_pressed)
	options_btn.pressed.connect(_on_options_button_pressed)
	exit_btn.pressed.connect(_on_exit_button_pressed)
	
	# Connect all dialogs
	quit_dialog.confirmed.connect(_on_quit_confirmed)
	delete_dialog.confirmed.connect(_on_delete_confirmed)
	
	# Initialize modal system
	modal_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.hide()

func _on_hit_timer_timeout() -> void:
	if title_anim.has_animation("title_bounce"): 
		title_anim.play("title_bounce")
	await get_tree().create_timer(BUTTON_DELAY).timeout
	if button_anim.has_animation("buttons_enter"):
		button_anim.play("buttons_enter")

func _unhandled_input(_event: InputEvent) -> void:
	# ESC key disabled on title screen
	pass

# --- Modal Management ---
func _open_modal(scene: PackedScene) -> Control:
	# Close any existing modal first
	if current_modal:
		_close_modal()
	
	var instance = scene.instantiate()
	modal_container.add_child(instance)
	modal_container.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.show()
	current_modal = instance
	return instance

func _close_modal() -> void:
	if current_modal and is_instance_valid(current_modal):
		current_modal.queue_free()
	
	# Clear all children from modal container
	for child in modal_container.get_children():
		child.queue_free()
	
	current_modal = null
	modal_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_layer.hide()

# --- Button Handlers ---
func _on_new_button_pressed() -> void:
	if current_modal and not is_instance_valid(current_modal):
		current_modal = null
	
	if current_modal:
		return
	
	var ui = _open_modal(CHAR_CREATE_SCENE)
	
	# Connect hover sounds for CharacterCreation buttons
	var start_button = ui.get_node_or_null("CenterContainer/VBoxContainer/ButtonContainer/StartButton")
	var cancel_button = ui.get_node_or_null("CenterContainer/VBoxContainer/ButtonContainer/CancelButton")

	if start_button:
		start_button.mouse_entered.connect(_on_button_hover)
		start_button.pressed.connect(_on_button_success)
	if cancel_button:
		cancel_button.mouse_entered.connect(_on_button_hover)
		cancel_button.pressed.connect(_on_button_cancel)
	
	# Connect signals if they exist
	if ui.has_signal("closed"):
		ui.closed.connect(_close_modal)

	if ui.has_signal("finished"):
		ui.finished.connect(_on_character_creation_finished)

func _on_load_button_pressed() -> void:
	if current_modal and not is_instance_valid(current_modal):
		current_modal = null
		
	if current_modal:
		return
	
	var ui = _open_modal(LOAD_MENU_SCENE)
	
	# Connect hover and click sounds for LoadMenu buttons
	await get_tree().process_frame
	var load_button = ui.get_node_or_null("VBoxContainer/ButtonContainer/LoadButton")
	var delete_button = ui.get_node_or_null("VBoxContainer/ButtonContainer/DeleteButton")
	var close_button = ui.get_node_or_null("VBoxContainer/ButtonContainer/CloseButton")

	if load_button:
		load_button.mouse_entered.connect(_on_button_hover)
		load_button.pressed.connect(_on_button_success)
	if delete_button:
		delete_button.mouse_entered.connect(_on_button_hover)
		delete_button.pressed.connect(_on_button_warning)
	if close_button:
		close_button.mouse_entered.connect(_on_button_hover)
		close_button.pressed.connect(_on_button_cancel)
	
	# Connect basic signals
	if ui.has_signal("closed"):
		ui.closed.connect(_close_modal)
	
	if ui.has_signal("file_chosen"):
		ui.file_chosen.connect(func(save_id: String):
			if is_instance_valid(self) and is_instance_valid(music):
				music.stop()
			if is_instance_valid(self):
				_close_modal()
				_fade_to_black()
				await get_tree().create_timer(1.5).timeout
				if is_instance_valid(self):
					_fade_to_loaded_game(save_id)
		)
	
	# Connect delete signal
	if ui.has_signal("delete_requested"):
		ui.delete_requested.connect(func(save_id: String):
			pending_delete_save_id = save_id
			_show_dialog_with_overlay(delete_dialog)
		)

func _on_options_button_pressed() -> void:
	if current_modal and not is_instance_valid(current_modal):
		current_modal = null
		
	if current_modal:
		return
	
	var ui = _open_modal(OPTIONS_MENU_SCENE)
	
	# Connect hover and click sounds for OptionsMenu
	var save_button = ui.get_node_or_null("OptionsContainer/SaveButton")

	if save_button:
		save_button.mouse_entered.connect(_on_button_hover)
		save_button.pressed.connect(_on_button_success)

	if ui.has_signal("closed"):
		ui.closed.connect(_close_modal)

	if ui.has_signal("option_changed"):
		ui.option_changed.connect(_save_option)

func _on_exit_button_pressed() -> void:
	exit_confirm_sound.play()
	if not (quit_dialog.visible or delete_dialog.visible):
		_show_dialog_with_overlay(quit_dialog)

# --- Dialog Handlers ---
func _on_quit_confirmed() -> void:
	_hide_dialog_overlay()
	get_tree().quit()

func _on_delete_confirmed() -> void:
	_hide_dialog_overlay()
	
	# Hide LoadMenu overlay too
	if current_modal and current_modal.has_method("hide_delete_overlay"):
		current_modal.hide_delete_overlay()
	
	if pending_delete_save_id != "":
		_delete_save_file(pending_delete_save_id)
		pending_delete_save_id = ""
		
		# Refresh the load menu if it's still open
		if current_modal and current_modal.has_method("refresh_save_list"):
			current_modal.refresh_save_list()

# --- Helper Methods ---
func is_modal_open() -> bool:
	return current_modal != null

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
	
	# Connect click sounds based on dialog type
	if dialog == quit_dialog:
		if cancel_btn and not cancel_btn.pressed.is_connected(_on_quit_dialog_cancel_pressed):
			cancel_btn.pressed.connect(_on_quit_dialog_cancel_pressed)
		if ok_btn and not ok_btn.pressed.is_connected(_on_quit_dialog_ok_pressed):
			ok_btn.pressed.connect(_on_quit_dialog_ok_pressed)
	elif dialog == delete_dialog:
		if cancel_btn and not cancel_btn.pressed.is_connected(_on_delete_dialog_cancel_pressed):
			cancel_btn.pressed.connect(_on_delete_dialog_cancel_pressed)
		if ok_btn and not ok_btn.pressed.is_connected(_on_delete_dialog_ok_pressed):
			ok_btn.pressed.connect(_on_delete_dialog_ok_pressed)

func _on_dialog_button_hover():
	button_hover_sound.play()

# Quit dialog sounds
func _on_quit_dialog_cancel_pressed():
	cancel_sound.play()
	_hide_dialog_overlay()

func _on_quit_dialog_ok_pressed():
	success_sound.play()

# Delete dialog sounds  
func _on_delete_dialog_cancel_pressed():
	cancel_sound.play()
	_hide_dialog_overlay()
	if current_modal and current_modal.has_method("hide_delete_overlay"):
		current_modal.hide_delete_overlay()

func _on_delete_dialog_ok_pressed():
	success_sound.play()

func _hide_dialog_overlay():
	dialog_overlay.hide()

func _fade_to_black() -> void:
	fade.show()
	fade.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 1.5)

# --- Game Flow Functions ---
func _start_opening_cutscene() -> void:
	get_tree().change_scene_to_file("res://scenes/cutscenes/PreGameCutscene1.tscn")

func _fade_to_loaded_game(_save_id: String) -> void:
	pass

func _save_option(_opt_name: String, _value: Variant) -> void:
	pass

func _delete_save_file(save_id: String) -> void:
	var save_path = "user://saves/" + save_id + ".dat"
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

# --- Helper Methods for Lambda Fixes ---
func _hide_fade_overlay():
	"""Hide fade overlay after fade-in completes."""
	if is_instance_valid(fade):
		fade.hide()

func _on_character_creation_finished():
	"""Handle character creation completion."""
	if is_instance_valid(self) and is_instance_valid(music):
		music.stop()
	if is_instance_valid(self):
		_close_modal()
		_fade_to_black()
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(self):
			_start_opening_cutscene()

func _on_button_hover():
	"""Play hover sound when mouse enters button."""
	if button_hover_sound:
		button_hover_sound.play()

func _on_button_success():
	"""Play success sound when button is pressed."""
	if success_sound:
		success_sound.play()

func _on_button_cancel():
	"""Play cancel sound when button is pressed."""
	if cancel_sound:
		cancel_sound.play()

func _on_button_warning():
	"""Play warning sound when button is pressed."""
	if warning_confirm_sound:
		warning_confirm_sound.play()
