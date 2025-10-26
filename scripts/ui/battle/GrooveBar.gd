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

# Lava lamp shader code (inline to avoid gitignored assets folder)
const LAVA_SHADER_CODE = """
shader_type canvas_item;

uniform bool use_rainbow = true;
uniform float speed = 0.3;

float noise(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = noise(i);
    float b = noise(i + vec2(1.0, 0.0));
    float c = noise(i + vec2(0.0, 1.0));
    float d = noise(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 4; i++) {
        value += amplitude * smooth_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

vec3 rainbow(float t) {
    vec3 a = vec3(0.5, 0.5, 0.5);
    vec3 b = vec3(0.5, 0.5, 0.5);
    vec3 c = vec3(1.0, 1.0, 1.0);
    vec3 d = vec3(0.0, 0.33, 0.67);
    return a + b * cos(6.28318 * (c * t + d));
}

vec3 grayscale(float t) {
    float gray = 0.3 + t * 0.4;
    return vec3(gray);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * speed;
    vec2 offset1 = vec2(time * 0.5, time * 0.3);
    vec2 offset2 = vec2(-time * 0.4, time * 0.6);
    float n1 = fbm(uv * 3.0 + offset1);
    float n2 = fbm(uv * 2.5 + offset2);
    float n = (n1 + n2) * 0.5;
    n += sin(uv.y * 10.0 + time * 2.0) * 0.1;
    vec3 color;
    if (use_rainbow) {
        color = rainbow(n);
    } else {
        color = grayscale(n);
    }
    float brightness = 0.8 + n * 0.4;
    color *= brightness;
    COLOR = vec4(color, 1.0);
}
"""

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50

		# Create lava lamp shader from inline code
		lava_shader = Shader.new()
		lava_shader.code = LAVA_SHADER_CODE

		lava_material = ShaderMaterial.new()
		lava_material.shader = lava_shader
		lava_material.set_shader_parameter("use_rainbow", true)  # Start with rainbow
		lava_material.set_shader_parameter("speed", 0.3)

		# Apply shader to progress bar fill
		var style_box = StyleBoxFlat.new()
		progress_bar.add_theme_stylebox_override("fill", style_box)

		# Create a ColorRect for shader effect
		var shader_rect = ColorRect.new()
		shader_rect.name = "LavaEffect"
		shader_rect.material = lava_material
		shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		progress_bar.add_child(shader_rect)
		shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shader_rect.z_index = -1  # Behind the label

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	progress_bar.value = percentage

	# Update percentage label
	if percentage_label:
		percentage_label.text = "%d%%" % int(percentage)

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
