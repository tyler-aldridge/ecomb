extends Control

# ============================================================================
# GROOVE BAR - Universal Battle Health System
# ============================================================================
# Displays groove with yellow (≤49%) to green (≥50%) gradient
# - Rainbow pulsing when full
# - Smooth color transitions
# - Rounded right side
# - Z-indexed to top
# - Tutorial message that pulses from center

@onready var progress_bar: ProgressBar = $ProgressBar

var current_percentage: float = 50.0
var rainbow_time: float = 0.0
var scanline_offset: float = 0.0
var is_full: bool = false
var pulse_time: float = 0.0
var is_warning_active: bool = false
var warning_color_tween: Tween = null
var warning_scale_tween: Tween = null
var full_groove_pulse_tween: Tween = null
var full_groove_glow_tween: Tween = null
var scanline_overlay: ColorRect = null

# Rainbow colors for full groove pulse
var rainbow_colors = [
	Color(1, 0, 0, 1),      # Red
	Color(1, 0.5, 0, 1),    # Orange
	Color(1, 1, 0, 1),      # Yellow
	Color(0, 1, 0, 1),      # Green
	Color(0, 1, 1, 1),      # Cyan
	Color(0, 0, 1, 1),      # Blue
	Color(0.56, 0, 1, 1)    # Violet
]

# Yellow to green gradient colors
var yellow_color = Color(1, 1, 0, 1)  # Yellow for ≤49%
var green_color = Color(0, 1, 0, 1)    # Green for ≥50%

func _ready():
	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.groove_changed.connect(_on_groove_changed)

	# Initialize progress bar
	if progress_bar:
		progress_bar.min_value = 0
		progress_bar.max_value = 100
		progress_bar.value = 50
		# Set initial color to green (50%)
		update_bar_color(50.0)

	# Create VHS scanline overlay (hidden until full)
	create_scanline_overlay()

func create_scanline_overlay():
	"""Create VHS-style scanline overlay with chromatic aberration and distortion."""
	scanline_overlay = ColorRect.new()
	scanline_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanline_overlay.visible = false

	# Create shader for dramatic VHS effect with RGB split and random distortion
	var shader_code = """
shader_type canvas_item;

uniform float offset : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_offset : hint_range(0.0, 10.0) = 0.0;

// Simple pseudo-random noise function
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Multiple wave frequencies for organic distortion
	float wave1 = sin((UV.y * 30.0) + distortion_offset * 2.0) * 0.008;
	float wave2 = sin((UV.y * 15.0) + distortion_offset * 1.5 + 1.3) * 0.004;
	float wave3 = sin((UV.y * 60.0) + distortion_offset * 3.0 + 2.7) * 0.003;
	float combined_wave = wave1 + wave2 + wave3;

	// Chromatic aberration (RGB split) - classic VHS effect
	float aberration = 0.003;
	vec2 uv_r = vec2(UV.x + combined_wave + aberration, UV.y);
	vec2 uv_g = vec2(UV.x + combined_wave, UV.y);
	vec2 uv_b = vec2(UV.x + combined_wave - aberration, UV.y);

	// Horizontal scanlines (more visible)
	float scanline = step(0.6, fract((UV.y * 25.0) + offset)) * 0.4;

	// Randomized vertical glitches (not uniform like a ruler)
	float glitch_pos = UV.x * 50.0 + distortion_offset * 0.3;
	float glitch_noise = random(vec2(floor(glitch_pos), floor(distortion_offset * 2.0)));
	float glitch = step(0.92, glitch_noise) * 0.3;  // Random glitch lines

	// Add more distortion at glitch positions
	if (glitch > 0.0) {
		float glitch_distort = random(vec2(floor(glitch_pos), floor(distortion_offset * 3.0))) * 0.02 - 0.01;
		combined_wave += glitch_distort;
	}

	// Combined darkening effect
	float darkness = scanline + glitch;

	// Apply darkening and VHS color shift
	COLOR.rgb *= (1.0 - darkness);
	COLOR.rgb += vec3(glitch * 0.15, 0.0, scanline * 0.05);  // Color tinting
	COLOR.a = darkness * 0.7;  // More visible overlay
}
"""

	var shader = Shader.new()
	shader.code = shader_code

	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader

	scanline_overlay.material = shader_material
	progress_bar.add_child(scanline_overlay)

	# Match progress bar size
	scanline_overlay.anchor_left = 0.0
	scanline_overlay.anchor_top = 0.0
	scanline_overlay.anchor_right = 1.0
	scanline_overlay.anchor_bottom = 1.0

func _process(delta):
	if is_full:
		# Fast horizontal flowing rainbow animation on bar when full
		if progress_bar:
			rainbow_time += delta * 3.5  # Faster flow speed for more visible effect
			if rainbow_time >= rainbow_colors.size():
				rainbow_time = 0.0

			var fill_style = progress_bar.get_theme_stylebox("fill")
			if fill_style and fill_style is StyleBoxFlat:
				# Cycle through rainbow colors with clear transitions
				var current_index = int(rainbow_time) % rainbow_colors.size()
				var next_index = (current_index + 1) % rainbow_colors.size()
				var t = rainbow_time - floor(rainbow_time)

				# Simple lerp for clean color transitions
				fill_style.bg_color = rainbow_colors[current_index].lerp(rainbow_colors[next_index], t)

		# Animate VHS scanlines scrolling and vertical distortion wave
		if scanline_overlay and scanline_overlay.material:
			scanline_offset += delta * 2.0  # Scroll speed
			if scanline_offset > 1.0:
				scanline_offset -= 1.0
			scanline_overlay.material.set_shader_parameter("offset", scanline_offset)
			scanline_overlay.material.set_shader_parameter("distortion_offset", rainbow_time * 2.0)

func _on_groove_changed(current_groove: float, max_groove: float):
	"""Update groove bar display when groove changes."""
	if not progress_bar:
		return

	var percentage = (current_groove / max_groove) * 100.0 if max_groove > 0 else 0.0
	current_percentage = percentage

	# Check if full for rainbow pulsing
	var was_full = is_full
	is_full = percentage >= 100.0

	# Start or stop full groove celebration animation
	if is_full and not was_full:
		play_full_groove_celebration()
	elif not is_full and was_full:
		stop_full_groove_celebration()

	# Animate the value change with smooth easing
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", percentage, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Update color based on groove level
	if not is_full:
		update_bar_color(percentage)

	# Play warning animation if low
	if percentage < 30.0:
		if not is_warning_active:
			play_low_groove_warning()
	else:
		stop_low_groove_warning()

func update_bar_color(percentage: float):
	"""Update bar fill color: yellow for ≤49%, green for ≥50%, smooth transition."""
	if not progress_bar:
		return

	var fill_style = progress_bar.get_theme_stylebox("fill")
	if fill_style and fill_style is StyleBoxFlat:
		if percentage <= 49.0:
			# Yellow for 49% and below
			fill_style.bg_color = yellow_color
		elif percentage >= 50.0 and percentage < 100.0:
			# Smooth transition from yellow to green between 49-51%
			if percentage < 51.0:
				var t = (percentage - 49.0) / 2.0  # 0.0 at 49%, 1.0 at 51%
				fill_style.bg_color = yellow_color.lerp(green_color, t)
			else:
				fill_style.bg_color = green_color

func play_low_groove_warning():
	"""Play warning animation when groove is low - red pulse (loops indefinitely)."""
	if is_warning_active:
		return  # Already playing
	
	is_warning_active = true
	
	# Flash red and pulse scale - INFINITE LOOPS
	warning_color_tween = create_tween()
	warning_color_tween.set_loops(0)  # 0 = infinite loops
	warning_color_tween.tween_property(self, "modulate", Color(1, 0.2, 0.2, 1), 0.3)
	warning_color_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)
	
	# Scale pulse at the same time
	warning_scale_tween = create_tween()
	warning_scale_tween.set_loops(0)  # 0 = infinite loops
	warning_scale_tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.3)
	warning_scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func stop_low_groove_warning():
	"""Stop the warning animation when groove recovers."""
	if not is_warning_active:
		return

	is_warning_active = false

	# Kill ONLY the warning tweens, not all tweens
	if warning_color_tween and is_instance_valid(warning_color_tween):
		warning_color_tween.kill()
		warning_color_tween = null

	if warning_scale_tween and is_instance_valid(warning_scale_tween):
		warning_scale_tween.kill()
		warning_scale_tween = null

	# Reset to normal appearance
	modulate = Color(1, 1, 1, 1)
	scale = Vector2(1.0, 1.0)

func play_full_groove_celebration():
	"""Show VHS scanline overlay when groove reaches 100%."""
	# Stop if already playing to restart
	stop_full_groove_celebration()

	# Show VHS scanline overlay
	if scanline_overlay:
		scanline_overlay.visible = true

func stop_full_groove_celebration():
	"""Hide VHS scanline overlay when groove drops below 100%."""
	# Hide VHS scanline overlay
	if scanline_overlay:
		scanline_overlay.visible = false
