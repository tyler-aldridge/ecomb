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

var lava_shader: Shader
var lava_material: ShaderMaterial
var shader_rect: ColorRect

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50

		# Load lava lamp shader from file
		lava_shader = load("res://assets/shaders/lava_lamp.gdshader")
		if lava_shader:
			lava_material = ShaderMaterial.new()
			lava_material.shader = lava_shader
			lava_material.set_shader_parameter("use_rainbow", true)  # Start with rainbow
			lava_material.set_shader_parameter("speed", 0.3)

			# Create a ColorRect with shader behind the progress bar
			shader_rect = ColorRect.new()
			shader_rect.name = "LavaEffect"
			shader_rect.material = lava_material
			shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

			# Add as sibling to progress bar (under VBoxContainer)
			var vbox = progress_bar.get_parent()
			vbox.add_child(shader_rect)
			vbox.move_child(shader_rect, progress_bar.get_index())  # Place before progress bar

			# Match progress bar size and position
			shader_rect.custom_minimum_size = progress_bar.custom_minimum_size
			shader_rect.size_flags_horizontal = progress_bar.size_flags_horizontal
			shader_rect.size_flags_vertical = progress_bar.size_flags_vertical

			# Make progress bar background transparent so shader shows through
			var transparent_bg = StyleBoxFlat.new()
			transparent_bg.bg_color = Color(0, 0, 0, 0)  # Fully transparent
			progress_bar.add_theme_stylebox_override("background", transparent_bg)
			progress_bar.add_theme_stylebox_override("fill", transparent_bg)

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	progress_bar.value = percentage

	# Update percentage label
	if percentage_label:
		percentage_label.text = "%d%%" % int(percentage)

	# Resize shader rect to show fill effect
	if shader_rect and progress_bar:
		var bar_width = progress_bar.size.x
		var fill_width = bar_width * (percentage / 100.0)
		shader_rect.custom_minimum_size.x = fill_width
		shader_rect.size.x = fill_width

	# Switch between rainbow (filling, >50%) and grayscale (missing, <50%)
	if lava_material:
		if percentage >= 50.0:
			lava_material.set_shader_parameter("use_rainbow", true)
		else:
			lava_material.set_shader_parameter("use_rainbow", false)

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
