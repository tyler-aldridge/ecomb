extends Control

# ============================================================================
# GROOVE BAR - Universal Battle Health System
# ============================================================================
# Displays the current groove percentage as a health bar
# Connects to BattleManager.groove_changed signal
#
# SCENE STRUCTURE (create in Godot editor):
# GrooveBar (Control) - this script
# ├─ Background (Panel or ColorRect)
# ├─ ProgressBar (ProgressBar)
# │   └─ Label (Label) - shows percentage "75%"
# └─ Title (Label) - shows "GROOVE"
#
# STYLING NOTES:
# - ProgressBar should have custom theme for colors
# - Green when > 50%, Yellow when 25-50%, Red when < 25%
# - Add visual effects for low groove warning

@onready var progress_bar: ProgressBar = $MarginContainer/VBoxContainer/ProgressBar
@onready var percentage_label: Label = $MarginContainer/VBoxContainer/ProgressBar/Label
@onready var title_label: Label = $MarginContainer/VBoxContainer/Title

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize progress bar with rainbow gradient
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50

		# Create rainbow gradient StyleBox
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(1, 1, 1, 1)
		style_box.set_border_width_all(0)

		# Create gradient
		var gradient = Gradient.new()
		gradient.set_offset(0, 0.0)
		gradient.set_color(0, Color(1, 0, 0, 1))  # Red
		gradient.set_offset(1, 0.2)
		gradient.set_color(1, Color(1, 1, 0, 1))  # Yellow
		gradient.set_offset(2, 0.4)
		gradient.set_color(2, Color(0, 1, 0, 1))  # Green
		gradient.set_offset(3, 0.6)
		gradient.set_color(3, Color(0, 1, 1, 1))  # Cyan
		gradient.set_offset(4, 0.8)
		gradient.set_color(4, Color(0, 0, 1, 1))  # Blue
		gradient.set_offset(5, 1.0)
		gradient.set_color(5, Color(1, 0, 1, 1))  # Magenta

		# Apply gradient as modulate (since StyleBoxFlat doesn't support gradients directly)
		# We'll use a shader or ColorRect workaround, but for now use solid rainbow effect
		progress_bar.modulate = Color(1, 1, 1, 1)

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	progress_bar.value = percentage

	# Update percentage label
	if percentage_label:
		percentage_label.text = "%d%%" % int(percentage)

	# Play warning animation if low
	if percentage < 25.0:
		play_low_groove_warning()

func play_low_groove_warning():
	"""Play warning animation when groove is low."""
	# Create a pulsing effect on the border
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate:a", 0.7, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
