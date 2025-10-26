extends Control

# ============================================================================
# GROOVE BAR - Universal Battle Health System
# ============================================================================
# Displays groove as a rainbow-filled bar with curved right edge
# - No background (transparent)
# - Bar originates from left, curved right side
# - Rainbow lava lamp fill
# - Empty space is transparent
# - Animates growth and shrinkage
# - Z-indexed to top

@onready var bar_fill: ColorRect = $MarginContainer/VBoxContainer/BarContainer/GrooveBarFill
@onready var bar_container: Control = $MarginContainer/VBoxContainer/BarContainer

var groove_shader: Shader
var groove_material: ShaderMaterial
var current_percentage: float = 50.0
var max_bar_width: float = 1920.0

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Wait for layout to complete
	await get_tree().process_frame

	# Get max width from screen size
	max_bar_width = get_viewport_rect().size.x

	# Load and apply groove bar shader
	groove_shader = load("res://assets/shaders/groove_bar.gdshader")
	if groove_shader and bar_fill:
		groove_material = ShaderMaterial.new()
		groove_material.shader = groove_shader
		groove_material.set_shader_parameter("speed", 0.3)
		groove_material.set_shader_parameter("curve_radius", 30.0)
		bar_fill.material = groove_material

		# Set initial width to 50% (starting groove)
		var initial_width = max_bar_width * 0.5
		bar_fill.offset_right = initial_width

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not bar_fill:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	current_percentage = percentage

	# Calculate target width based on percentage
	var target_width = max_bar_width * (percentage / 100.0)

	# Animate the width change with smooth easing
	var tween = create_tween()
	tween.tween_property(bar_fill, "offset_right", target_width, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Play warning animation if low
	if percentage < 25.0:
		play_low_groove_warning()

func play_low_groove_warning():
	"""Play warning animation when groove is low."""
	# Create a pulsing effect
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(self, "modulate:a", 0.7, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
