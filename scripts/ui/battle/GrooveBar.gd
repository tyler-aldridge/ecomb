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

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var percentage_label: Label = $ProgressBar/Label
@onready var title_label: Label = $Title

# Color thresholds
const COLOR_HIGH = Color(0.0, 1.0, 0.0)    # Green
const COLOR_MED = Color(1.0, 1.0, 0.0)     # Yellow
const COLOR_LOW = Color(1.0, 0.0, 0.0)      # Red

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	progress_bar.value = percentage

	# Update percentage label
	if percentage_label:
		percentage_label.text = "%d%%" % int(percentage)

	# Update color based on groove level
	update_color(percentage)

	# Play warning animation if low
	if percentage < 25.0:
		play_low_groove_warning()

func update_color(percentage: float):
	"""Update progress bar color based on groove percentage."""
	if not progress_bar:
		return

	var color = COLOR_HIGH
	if percentage < 25.0:
		color = COLOR_LOW
	elif percentage < 50.0:
		color = COLOR_MED

	# Apply color to progress bar (requires custom theme or modulate)
	progress_bar.modulate = color

func play_low_groove_warning():
	"""Play warning animation when groove is low."""
	# Create a pulsing effect
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate:a", 0.5, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
