extends Control

# ============================================================================
# BATTLE FAILURE - Simple failure dialog
# ============================================================================
# Shows when player fails a battle (groove reaches 0%)
# Follows same pattern as MainTitle's QuitDialog:
# - Simple modal with "Restart" and "Exit to Title" buttons
# - Pauses the game
# - Cannot be dismissed (no Cancel, no ESC) - must choose action
#
# Connects to BattleManager.battle_failed signal
# NOTE: Battle SUCCESS uses detailed stats screen (BattleResults.gd)

@onready var dialog: ConfirmationDialog = $FailureDialog
@onready var dialog_overlay: ColorRect = $DialogOverlay

# Sound effects
@onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
@onready var restart_sound: AudioStreamPlayer = $RestartSound
@onready var quit_sound: AudioStreamPlayer = $QuitSound
@onready var battle_failure_sound: AudioStreamPlayer = $BattleFailureSound

# Fade overlay for scene transitions
var fade_rect: ColorRect

func _ready():
	visible = false
	dialog_overlay.hide()
	dialog.hide()

	# Create fade overlay for scene transitions
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.z_index = 1000
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)

	# Connect to BattleManager
	if BattleManager:
		BattleManager.battle_failed.connect(_on_battle_failed)

	# Disable close button (can't dismiss, must choose)
	dialog.unresizable = true

	# Connect dialog signals
	dialog.confirmed.connect(_on_exit_confirmed)
	dialog.canceled.connect(_on_restart_confirmed)

	# Connect hover sounds to dialog buttons (deferred to allow dialog to initialize)
	call_deferred("_connect_dialog_button_sounds")

func _on_battle_failed():
	"""Show failure dialog when battle fails."""
	visible = true
	dialog_overlay.show()
	get_tree().paused = true
	dialog.popup_centered()

	# Play failure sound when dialog appears
	if battle_failure_sound:
		battle_failure_sound.play()

func _on_restart_confirmed():
	"""Restart the battle."""
	if restart_sound:
		restart_sound.play()

	# Fade to black then restart
	_fade_to_black()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_confirmed():
	"""Exit to title screen."""
	if quit_sound:
		quit_sound.play()

	# Fade to black then exit
	_fade_to_black()
	await get_tree().create_timer(1.5).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func _fade_to_black():
	"""Fade overlay to black for scene transition."""
	if not is_instance_valid(fade_rect):
		return
	fade_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 1.5)

func _connect_dialog_button_sounds():
	"""Connect hover sounds to dialog buttons and adjust button spacing."""
	var ok_btn = dialog.get_ok_button()
	var cancel_btn = dialog.get_cancel_button()

	# Connect hover sounds
	if ok_btn and button_hover_sound:
		ok_btn.mouse_entered.connect(func(): button_hover_sound.play())
	if cancel_btn and button_hover_sound:
		cancel_btn.mouse_entered.connect(func(): button_hover_sound.play())

	# Adjust spacing between buttons
	# The buttons are in an HBoxContainer, find it and adjust separation
	if ok_btn and ok_btn.get_parent() is HBoxContainer:
		var button_container = ok_btn.get_parent() as HBoxContainer
		button_container.add_theme_constant_override("separation", 30)
