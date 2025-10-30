extends Label

# ============================================================================
# XP POPUP - Shows XP gain floating text
# ============================================================================
# Connects to BattleManager.hit_registered signal
# Displays "+5XP", "+10XP" etc.
# - White text for GOOD/OKAY hits
# - Rainbow text for PERFECT hits
# - Pops in with scale, floats up, then fades out
# Positioned ~100px above combo display

var is_perfect: bool = false
var xp_amount: int = 0
var active_tween: Tween = null

# FIXED offset position - matches what BattleManager sets (scripts/autoload/BattleManager.gd:724)
# Position (-150, -170): -150 centers the 300px wide label, -170 places it above sprite
const BASE_OFFSET = Vector2(-150, -170)

# Rainbow colors
var rainbow_colors = [
	Color(1, 0, 0, 1),    # Red
	Color(1, 0.5, 0, 1),  # Orange
	Color(1, 1, 0, 1),    # Yellow
	Color(0, 1, 0, 1),    # Green
	Color(0, 1, 1, 1),    # Cyan
	Color(0, 0, 1, 1),    # Blue
	Color(1, 0, 1, 1)     # Magenta
]
var color_index: float = 0.0

func _ready():
	# Start invisible
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)

	# Connect to BattleManager signals
	if BattleManager:
		BattleManager.hit_registered.connect(_on_hit_registered)

func _on_hit_registered(quality: String, strength_gain: int, _groove_change: float):
	"""Show XP popup when hit is registered."""
	if strength_gain > 0:
		show_xp(strength_gain, quality == "PERFECT")

func show_xp(amount: int, perfect: bool = false):
	"""Show XP popup with amount - always white."""
	xp_amount = amount
	is_perfect = perfect

	# Update text
	text = "+%dXP" % amount

	# Always white (no rainbow effect)
	modulate = Color(1, 1, 1, 1)

	# Animate popup
	play_popup_animation()

# Removed _process - not needed (was empty)

func _reset_display():
	"""Reset display state - called by tween callback."""
	if is_instance_valid(self):
		position = BASE_OFFSET
		scale = Vector2(0.5, 0.5)
		modulate.a = 0.0
		active_tween = null

func play_popup_animation():
	"""Animate the popup: scale in, float up, fade out - ALWAYS resets to BASE_OFFSET."""
	# Kill any existing tween to prevent overlap
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# ALWAYS reset position to base offset before starting animation
	# This prevents drift from accumulated position changes
	position = BASE_OFFSET

	var float_up_distance = 80.0  # Float up 80px

	# Ensure we're at starting scale and alpha
	scale = Vector2(0.5, 0.5)
	modulate.a = 0.0

	active_tween = create_tween()
	active_tween.set_parallel(true)

	# Scale in quickly
	active_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	active_tween.tween_property(self, "modulate:a", 1.0, 0.1)

	# Hold at full size and visibility
	active_tween.chain()
	active_tween.tween_interval(0.3)

	# Float up and fade out
	active_tween.set_parallel(true)
	active_tween.tween_property(self, "position:y", BASE_OFFSET.y - float_up_distance, 0.8).set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.3)

	# Reset to BASE_OFFSET (not whatever position was before)
	active_tween.chain().tween_callback(_reset_display)
