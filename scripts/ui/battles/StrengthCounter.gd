extends Control

# ============================================================================
# STRENGTH COUNTER - Shows XP gained during battle
# ============================================================================
# Displays total Strength earned with counting animation
# Connects to BattleManager.strength_gained signal
#
# SCENE STRUCTURE:
# StrengthCounter (Control) - this script
# └─ VBoxContainer
#     ├─ TitleLabel - shows "STRENGTH"
#     └─ CounterLabel - shows "+3,450"

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var counter_label: Label = $VBoxContainer/CounterLabel

var display_value: int = 0

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.strength_gained.connect(_on_strength_gained)

	# Initialize
	update_display()

func _on_strength_gained(amount: int, total: int):
	"""Update strength display with animation."""
	# Animate the counter
	animate_strength_gain(amount, total)

func animate_strength_gain(amount: int, new_total: int):
	"""Animate the strength counter increasing."""
	if not counter_label:
		return

	# Flash effect for the gain
	var flash_tween = create_tween()
	flash_tween.tween_property(counter_label, "modulate", Color(1, 1, 0, 1), 0.1)
	flash_tween.tween_property(counter_label, "modulate", Color(1, 1, 1, 1), 0.2)

	# Count up animation
	var count_tween = create_tween()
	count_tween.tween_method(set_display_value, display_value, new_total, 0.3)

func set_display_value(value: int):
	"""Set the displayed value (for tween animation)."""
	display_value = value
	update_display()

func update_display():
	"""Update the label text."""
	if counter_label:
		counter_label.text = "+%d" % display_value
