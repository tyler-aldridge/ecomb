extends Control

# ============================================================================
# COMBO DISPLAY - Shows current combo and multiplier
# ============================================================================
# Displays combo count and multiplier with celebration effects
# Connects to BattleManager.combo_changed and combo_milestone_reached signals
#
# SCENE STRUCTURE (create in Godot editor):
# ComboDisplay (Control) - this script
# ├─ ComboLabel (Label) - shows "42 COMBO!"
# ├─ MultiplierLabel (Label) - shows "3.0x"
# └─ MilestoneLabel (Label) - shows milestone messages "10 HIT COMBO!"
#
# STYLING NOTES:
# - ComboLabel should be large and bold
# - MultiplierLabel should change color based on multiplier (1x, 1.5x, 2x, 2.5x, 3x)
# - MilestoneLabel should be even larger and animate in/out
# - Add particle effects or screen shake for milestones

@onready var combo_label: Label = $ComboLabel
@onready var multiplier_label: Label = $MultiplierLabel
@onready var milestone_label: Label = $MilestoneLabel

# Multiplier colors (visual feedback for progression)
const MULTIPLIER_COLORS = {
	1.0: Color(1.0, 1.0, 1.0),    # White - base
	1.5: Color(0.5, 1.0, 1.0),    # Cyan - good
	2.0: Color(0.3, 1.0, 0.3),    # Green - great
	2.5: Color(1.0, 1.0, 0.3),    # Yellow - amazing
	3.0: Color(1.0, 0.5, 0.0)     # Orange - MAX!
}

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.combo_changed.connect(_on_combo_changed)
		BattleManager.combo_milestone_reached.connect(_on_combo_milestone_reached)

	# Initialize
	if milestone_label:
		milestone_label.visible = false
		milestone_label.modulate.a = 0.0

	update_display(0, 1.0)

func _on_combo_changed(current_combo: int, multiplier: float):
	"""Update combo display when combo changes."""
	update_display(current_combo, multiplier)

func update_display(combo: int, multiplier: float):
	"""Update all labels with current combo/multiplier."""
	# Update combo count
	if combo_label:
		if combo > 0:
			combo_label.text = "%d COMBO!" % combo
			combo_label.visible = true
		else:
			combo_label.visible = false

	# Update multiplier
	if multiplier_label:
		if multiplier > 1.0:
			multiplier_label.text = "%.1fx" % multiplier
			multiplier_label.visible = true
			# Update color based on multiplier
			multiplier_label.modulate = get_multiplier_color(multiplier)
		else:
			multiplier_label.visible = false

func get_multiplier_color(multiplier: float) -> Color:
	"""Get color for current multiplier level."""
	# Find the closest defined multiplier color
	for mult in MULTIPLIER_COLORS.keys():
		if multiplier <= mult:
			return MULTIPLIER_COLORS[mult]
	return MULTIPLIER_COLORS[3.0]  # Max color

func _on_combo_milestone_reached(combo: int, multiplier: float):
	"""Show celebration when reaching combo milestones (10, 20, 30, 40)."""
	if not milestone_label:
		return

	# Set milestone text
	var milestone_text = ""
	match combo:
		10:
			milestone_text = "10 HIT COMBO!"
		20:
			milestone_text = "20 HIT COMBO!"
		30:
			milestone_text = "30 HIT COMBO!"
		40:
			milestone_text = "MAX COMBO POWER!"
		_:
			if combo >= 40:
				milestone_text = "LEGENDARY!"

	milestone_label.text = milestone_text
	milestone_label.modulate = get_multiplier_color(multiplier)

	# Animate milestone label
	play_milestone_animation()

func play_milestone_animation():
	"""Animate milestone label with scale and fade."""
	if not milestone_label:
		return

	milestone_label.visible = true
	milestone_label.scale = Vector2(0.5, 0.5)
	milestone_label.modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)

	# Scale up
	tween.tween_property(milestone_label, "scale", Vector2(1.5, 1.5), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Fade in
	tween.tween_property(milestone_label, "modulate:a", 1.0, 0.2)

	# Chain: hold, then fade out
	tween.chain()
	tween.tween_interval(1.5)
	tween.tween_property(milestone_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): milestone_label.visible = false)
