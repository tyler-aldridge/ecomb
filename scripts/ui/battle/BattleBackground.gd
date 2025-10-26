extends ColorRect

# ============================================================================
# BATTLE BACKGROUND - Universal Battle Background System
# ============================================================================
# Handles animated backgrounds for battles
# Supports different styles via shader parameter
# - "vaporwave": Shifting pink/purple/cyan gradient (default)
# - Future: Add more styles as needed

@export var background_style: String = "vaporwave"
@export var animation_speed: float = 0.5

var background_shader: Shader
var background_material: ShaderMaterial

func _ready():
	# Apply background shader based on style
	apply_background_shader()

func apply_background_shader():
	"""Apply background shader based on selected style."""
	match background_style:
		"vaporwave":
			background_shader = load("res://assets/shaders/background_swirl.gdshader")
			if background_shader:
				background_material = ShaderMaterial.new()
				background_material.shader = background_shader
				background_material.set_shader_parameter("speed", animation_speed)
				material = background_material
		_:
			# Default to vaporwave
			push_warning("Unknown background style: %s, using vaporwave" % background_style)
			background_style = "vaporwave"
			apply_background_shader()

func set_background_style(style: String):
	"""Change background style at runtime."""
	background_style = style
	apply_background_shader()

func set_animation_speed(speed: float):
	"""Change animation speed at runtime."""
	animation_speed = speed
	if background_material:
		background_material.set_shader_parameter("speed", speed)
