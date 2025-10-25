extends Control

# ============================================================================
# BATTLE RESULTS - End-of-battle results screen
# ============================================================================
# Shows battle completion stats and level-up notifications
# Connects to BattleManager.battle_completed signal
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
@onready var quit_button: Button = $CanvasLayer/Panel/VBoxContainer/ButtonContainer/QuitButton

var battle_results: Dictionary = {}

func _ready():
	# Hide by default
	visible = false

	# Connect to BattleManager
	if BattleManager:
		BattleManager.battle_completed.connect(_on_battle_completed)

	# Connect buttons
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_battle_completed(results: Dictionary):
	"""Show battle results when battle completes."""
	battle_results = results
	show_results()

func show_results():
	"""Display the battle results."""
	visible = true

	# Check if battle was completed or failed
	var completed = battle_results.get("battle_completed", false)

	# Update title
	if title_label:
		title_label.text = "BATTLE COMPLETE!" if completed else "BATTLE FAILED!"
		title_label.modulate = Color.GREEN if completed else Color.RED

	# Update stats
	if strength_earned_label:
		strength_earned_label.text = "Strength Earned: %d" % battle_results.get("strength_total", 0)

	if strength_awarded_label:
		var awarded = battle_results.get("strength_awarded", 0)
		strength_awarded_label.text = "Strength Awarded: %d" % awarded
		strength_awarded_label.visible = completed

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

	# Check for level up
	if level_up_label:
		var player_level = GameManager.get_player_level()
		level_up_label.text = "LEVEL UP! Now Level %d!" % player_level
		level_up_label.visible = false  # TODO: Check if actually leveled up

	# Show restart button only if failed
	if restart_button:
		restart_button.visible = not completed

func _on_continue_pressed():
	"""Continue to next scene or return to title."""
	# TODO: Navigate to appropriate next scene
	get_tree().change_scene_to_file("res://scenes/ui/title/MainTitle.tscn")

func _on_restart_pressed():
	"""Restart the battle."""
	# Reload current scene
	get_tree().reload_current_scene()

func _on_quit_pressed():
	"""Quit to title screen."""
	get_tree().change_scene_to_file("res://scenes/ui/title/MainTitle.tscn")
