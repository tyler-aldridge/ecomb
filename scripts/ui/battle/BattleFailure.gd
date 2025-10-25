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

# TODO: Add sound effect nodes like MainTitle
# @onready var warning_sound: AudioStreamPlayer = $WarningSound
# @onready var button_hover_sound: AudioStreamPlayer = $ButtonHoverSound
# @onready var restart_sound: AudioStreamPlayer = $RestartSound
# @onready var quit_sound: AudioStreamPlayer = $QuitSound

func _ready():
	visible = false
	dialog_overlay.hide()
	dialog.hide()

	# Connect to BattleManager
	if BattleManager:
		BattleManager.battle_failed.connect(_on_battle_failed)

	# Set up dialog
	dialog.dialog_text = "Battle Failed!\nGroove reached 0%"
	dialog.title = "BATTLE FAILED"
	dialog.ok_button_text = "Restart"
	dialog.cancel_button_text = "Exit to Title"

	# Disable close button (can't dismiss, must choose)
	dialog.unresizable = true

	# Connect dialog signals
	dialog.confirmed.connect(_on_restart_confirmed)
	dialog.canceled.connect(_on_exit_confirmed)

func _on_battle_failed():
	"""Show failure dialog when battle fails."""
	visible = true
	dialog_overlay.show()
	get_tree().paused = true
	dialog.popup_centered()

	# TODO: Play warning sound
	# warning_sound.play()

func _on_restart_confirmed():
	"""Restart the battle."""
	# TODO: Play restart sound
	# restart_sound.play()

	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_exit_confirmed():
	"""Exit to title screen."""
	# TODO: Play quit sound
	# quit_sound.play()

	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")
