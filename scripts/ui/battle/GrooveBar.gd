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

		# Set progress bar background to grey, fill to transparent
		var grey_bg = StyleBoxFlat.new()
		grey_bg.bg_color = Color(0.3, 0.3, 0.3, 1)  # Grey for empty portion
		progress_bar.add_theme_stylebox_override("background", grey_bg)

		var transparent_fill = StyleBoxFlat.new()
		transparent_fill.bg_color = Color(0, 0, 0, 0)
		progress_bar.add_theme_stylebox_override("fill", transparent_fill)

		# Wait for size to be available before creating shader
		await get_tree().process_frame

		# Load lava lamp shader from file
		lava_shader = load("res://assets/shaders/lava_lamp.gdshader")
		if lava_shader:
			lava_material = ShaderMaterial.new()
			lava_material.shader = lava_shader
			lava_material.set_shader_parameter("use_rainbow", true)  # Always rainbow
			lava_material.set_shader_parameter("speed", 0.3)

			# Create a ColorRect with shader for the filled portion
			shader_rect = ColorRect.new()
			shader_rect.name = "LavaEffect"
			shader_rect.material = lava_material
			shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

			# Add as child of progress bar
			progress_bar.add_child(shader_rect)
			shader_rect.anchor_left = 0.0
			shader_rect.anchor_top = 0.0
			shader_rect.anchor_right = 0.0
			shader_rect.anchor_bottom = 1.0
			shader_rect.offset_left = 0.0
			shader_rect.offset_top = 0.0
			shader_rect.offset_right = progress_bar.size.x * 0.5  # Start at 50%
			shader_rect.offset_bottom = 0.0
			shader_rect.z_index = -1  # Behind the percentage label

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	progress_bar.value = percentage

	# Animate resize of shader rect to show fill effect (rainbow fills from left)
	if shader_rect:
		var bar_width = progress_bar.size.x
		var fill_width = bar_width * (percentage / 100.0)

		# Animate the width change
		var tween = create_tween()
		tween.tween_property(shader_rect, "offset_right", fill_width, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

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
