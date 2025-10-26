extends Control

# ============================================================================
# BATTLE RESULTS - End-of-battle SUCCESS screen
# ============================================================================
# Shows detailed battle completion stats for SUCCESSFUL battles only:
# - Hit breakdown (PERFECT, GOOD, OKAY, MISS counts)
# - Total XP earned and awarded
# - Max combo achieved
# - Level up notifications
# - Battle name and "You did it!" message
#
# Connects to BattleManager.battle_completed signal
# NOTE: Battle FAILURE uses a separate simple dialog (BattleFailure.gd)
#
# SCENE STRUCTURE:
# BattleResults (Control) - this script
# └─ CanvasLayer (always on top)
#     └─ Panel (semi-transparent overlay)
#         └─ VBoxContainer
#             ├─ TitleLabel - "BATTLE COMPLETE!" or "BATTLE FAILED!"
#             ├─ StatsContainer - shows hit counts, combo, strength
#             ├─ LevelUpLabel - shows level up notification
#             └─ ButtonContainer - Continue, Restart, Quit buttons

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var title_label: Label = $CanvasLayer/Panel/VBoxContainer/TitleLabel
@onready var strength_earned_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/StrengthEarnedLabel
@onready var strength_awarded_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/StrengthAwardedLabel
@onready var max_combo_label: Label = $CanvasLayer/Panel/VBoxContainer/StatsContainer/MaxComboLabel
@onready var perfect_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/PerfectLabel
@onready var good_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/GoodLabel
@onready var okay_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/OkayLabel
@onready var miss_count_label: Label = $CanvasLayer/Panel/VBoxContainer/HitBreakdown/MissLabel
@onready var level_up_label: Label = $CanvasLayer/Panel/VBoxContainer/LevelUpLabel
@onready var continue_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/ContinueButton
@onready var restart_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/RestartButton
var battle_results: Dictionary = {}

func _ready():
	# Start hidden - will only show when explicitly called
	visible = false
	if canvas_layer:
		canvas_layer.visible = false

	# DO NOT auto-connect to BattleManager signal
	# Results will be shown manually by the battle scene when appropriate

	# Connect buttons
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
		continue_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
		restart_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		quit_button.mouse_entered.connect(func(): if button_hover_sound: button_hover_sound.play())

func _exit_tree():
	"""Clean up when scene is freed."""
	# Ensure we disconnect any lingering signal connections if they exist
	# (though we don't auto-connect anymore, this is a safety measure)
	if BattleManager and BattleManager.battle_completed.is_connected(Callable(self, "_on_battle_completed")):
		BattleManager.battle_completed.disconnect(Callable(self, "_on_battle_completed"))

func show_battle_results(results: Dictionary):
	"""Show battle results - called manually by battle scene at end."""
	battle_results = results
	show_results()

func show_results():
	"""Display the battle results for successful completion."""
	visible = true
	if canvas_layer:
		canvas_layer.visible = true

	# Pause the game
	get_tree().paused = true

	# Update title - Always success (failure uses BattleFailure dialog)
	if title_label:
		title_label.text = "YOU DID IT!"
		title_label.modulate = Color.GREEN

	# Update stats
	if strength_earned_label:
	var strength_total = battle_results.get("strength_total", 0)
	var strength_awarded = battle_results.get("strength_awarded", 0)

	if strength_earned_label:
		strength_earned_label.text = "Earned %d of %d Strength" % [strength_awarded, strength_total]

	# Hide the redundant second label

	if max_combo_label:
		max_combo_label.text = "Max Combo: %d" % battle_results.get("combo_max", 0)

	# Update hit breakdown
	var hit_counts = battle_results.get("hit_counts", {})
	if perfect_count_label:
		perfect_count_label.text = "PERFECT: %d" % hit_counts.get("PERFECT", 0)
	if good_count_label:
		good_count_label.text = "GOOD: %d" % hit_counts.get("GOOD", 0)
	if okay_count_label:
		okay_count_label.text = "OKAY: %d" % hit_counts.get("OKAY", 0)
	if miss_count_label:
		miss_count_label.text = "MISS: %d" % hit_counts.get("MISS", 0)

	# Check for level up (compare strength before and after)
	if level_up_label and GameManager:
		# The level up already happened in fade_to_title(), just check if we leveled
		# We can't easily track this without storing old level, so hide for now
		# User will see level up in future implementation
		level_up_label.visible = false

	# Hide restart button (only for success - failure has its own dialog)
	if restart_button:
		restart_button.visible = true

func _on_continue_pressed():
	if success_sound:
		success_sound.play()
	"""Continue to next scene or return to title."""
	get_tree().paused = false
	# For now, go to title. Later: navigate to overworld or next battle
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")

func _on_restart_pressed():
	if restart_sound:
		restart_sound.play()
	"""Restart the battle."""
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_pressed():
	if cancel_sound:
		cancel_sound.play()
	"""Quit to title screen."""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title/MainTitle.tscn")
