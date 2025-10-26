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

func _process(_delta):
	# No color cycling - always white
	pass

func play_popup_animation():
	"""Animate the popup: scale in, fade out - IN PLACE (no movement)."""
	# Kill any existing tweens to prevent drift
	var existing_tweens = get_tree().get_processed_tweens()
	for tween in existing_tweens:
		if tween.is_valid():
			var bound_node = tween.get_bound_node()
			if bound_node == self:
				tween.kill()

	# Ensure we're at starting scale and alpha
	scale = Vector2(0.5, 0.5)
	modulate.a = 0.0

	var tween = create_tween()
	tween.set_parallel(true)

	# Scale in quickly
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)

	# Hold at full size and visibility
	tween.chain()
	tween.tween_interval(0.4)

	# Fade out
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)

	# Reset to starting state
	tween.chain()
	tween.tween_callback(func():
		scale = Vector2(0.5, 0.5)
		modulate.a = 0.0
	)
