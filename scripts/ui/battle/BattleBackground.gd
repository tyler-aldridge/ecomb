extends ColorRect

# ============================================================================
# BATTLE BACKGROUND - Universal Battle Background System
# ============================================================================
# Handles animated backgrounds for battles
# Supports different styles via shader parameter
# - "vaporwave": Shifting pink/purple/cyan gradient (default)
# - Future: Add more styles as needed

@export var background_style: String = "vaporwave"
@export var use_bpm_sync: bool = true  # Sync animation to BPM (quarter rate)
@export var manual_speed: float = 1.5  # Used if use_bpm_sync is false

var background_shader: Shader
var background_material: ShaderMaterial
var cached_bpm: float = 0.0

func _ready():
	# Apply background shader based on style
	apply_background_shader()
	# Update animation speed based on BPM
	_update_animation_speed()

	# Connect to BattleManager to update when BPM changes (avoids checking every frame)
	if use_bpm_sync and BattleManager:
		# Update immediately and cache BPM
		_update_animation_speed()

func _process(_delta):
	# Only update if BPM has changed (not every frame)
	if use_bpm_sync and BattleManager and BattleManager.current_bpm != cached_bpm:
		_update_animation_speed()

func _update_animation_speed():
	"""Update animation speed based on BPM (quarter rate) or manual setting."""
	var speed: float
	if use_bpm_sync:
		var bpm = BattleManager.current_bpm if BattleManager else 120.0
		cached_bpm = bpm
		# Quarter BPM rate for subtle background animation
		speed = (bpm / 60.0) / 4.0
	else:
		speed = manual_speed

	if background_material:
		background_material.set_shader_parameter("speed", speed)

func apply_background_shader():
	"""Apply background shader based on selected style."""
	match background_style:
		"vaporwave":
			background_shader = load("res://assets/shaders/background_swirl.gdshader")
			if background_shader:
				background_material = ShaderMaterial.new()
				background_material.shader = background_shader
				# Speed will be set by _update_animation_speed()
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
	"""Change animation speed at runtime (disables BPM sync)."""
	use_bpm_sync = false
	manual_speed = speed
	if background_material:
		background_material.set_shader_parameter("speed", speed)
