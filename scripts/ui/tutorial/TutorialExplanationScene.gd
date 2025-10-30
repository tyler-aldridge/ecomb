extends Control

## ============================================================================
## SCENE 2: TUTORIAL EXPLANATION SCENE
## ============================================================================
## Step-by-step tutorial explaining game mechanics with visual highlights.
##
## Steps:
## 1. Groove Bar Explanation (yellow border around groove bar)
## 2. XP System Explanation (yellow border around player sprite)
## 3. Hit Zones Explanation (yellow indicators on hit zones)
## 4. Combo System (visual demonstration with fake notes)
##
## Each step has:
## - Yellow flashing border around relevant UI element
## - Centered typewriter text explanation
## - 5 second auto-advance or player input to skip
## ============================================================================

# Scene configuration
@export var next_scene_path: String = "res://scenes/tutorial/TutorialCalibrationScene.tscn"
@export var fade_duration: float = 3.0

# UI elements
var background: ColorRect
var groove_bar: Control
var player_sprite: AnimatedSprite2D
var hit_zones: Array = []
var typewriter: TypewriterText
var fade_overlay: ColorRect

# Tutorial borders
var current_border: Control
var border_tween: Tween

# State
var current_step: int = 0
var is_transitioning: bool = false

# Tutorial steps data
var tutorial_steps = [
	{
		"title": "THE GROOVE BAR",
		"messages": [
			"This shows your rhythm consistency.",
			"Perfect timing fills the groove bar. Miss too many beats and it empties.",
			"If it hits zero, you lose the battle!"
		],
		"highlight": "groove_bar"
	},
	{
		"title": "XP & PROGRESSION",
		"messages": [
			"Your XP gains will show here over your character.",
			"Perfect hits = Maximum XP, Good hits = Decent XP, Okay hits = Some XP, Misses = Zero XP",
			"Every battle has a maximum XP you can gain. The better your timing, the better your gains!"
		],
		"highlight": "player_sprite"
	},
	{
		"title": "HIT ZONES",
		"messages": [
			"These are the note hit zones. Hit 1, 2, or 3 on your keyboard when notes reach the zone in time with the beat!",
			"Perfect hits will line up exactly or dead center with these areas.",
			"Move to the groove of the song and you'll get some great gains!"
		],
		"highlight": "hit_zones"
	},
	{
		"title": "COMBO SYSTEM",
		"messages": [
			"Chain perfect hits for bonus XP! The longer your combos, the more XP rewards you'll receive.",
			"Break the combo, and you're back to square one. Master the rhythm, master the rewards!",
			"Now let's take a second to calibrate your system with the rhythm of the game."
		],
		"highlight": "none"
	}
]

func _ready():
	setup_ui()
	fade_from_black()

func setup_ui():
	"""Create the tutorial UI elements."""
	# Black background
	background = ColorRect.new()
	background.color = Color.BLACK
	background.size = get_viewport().get_visible_rect().size
	background.position = Vector2.ZERO
	add_child(background)

	# Create groove bar (simplified version)
	groove_bar = create_mock_groove_bar()
	add_child(groove_bar)

	# Create player sprite placeholder
	player_sprite = create_mock_player_sprite()
	add_child(player_sprite)

	# Create hit zones
	hit_zones = create_mock_hit_zones()
	for zone in hit_zones:
		add_child(zone)

	# Create typewriter text
	typewriter = TypewriterText.new()
	typewriter.size = get_viewport().get_visible_rect().size
	typewriter.auto_advance_delay = 5.0  # 5 seconds for tutorial
	add_child(typewriter)

	# Connect signals
	typewriter.advance_requested.connect(_on_advance_requested)

	# Create fade overlay
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.position = Vector2.ZERO
	fade_overlay.z_index = 100
	add_child(fade_overlay)

func create_mock_groove_bar() -> Control:
	"""Create simplified groove bar for tutorial."""
	var container = Control.new()
	container.position = Vector2(0, 20)
	container.size = Vector2(1920, 60)

	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2)
	bar_bg.size = Vector2(1200, 40)
	bar_bg.position = Vector2(360, 10)
	container.add_child(bar_bg)

	var bar_fill = ColorRect.new()
	bar_fill.color = Color.CYAN
	bar_fill.size = Vector2(600, 40)  # 50% filled
	bar_fill.position = Vector2(360, 10)
	container.add_child(bar_fill)

	return container

func create_mock_player_sprite() -> AnimatedSprite2D:
	"""Create player sprite placeholder."""
	var sprite = AnimatedSprite2D.new()
	sprite.position = Vector2(300, 800)
	# TODO: Load actual player sprite
	return sprite

func create_mock_hit_zones() -> Array:
	"""Create hit zones matching Lesson1Battle layout."""
	var zones = []

	# Use same positions as BattleManager.HIT_ZONE_POSITIONS
	var lane_positions = [
		Vector2(610.0, 650.0),   # Lane 1
		Vector2(860.0, 650.0),   # Lane 2
		Vector2(1110.0, 650.0)   # Lane 3
	]

	for i in range(3):
		var zone = ColorRect.new()
		zone.color = Color(1, 1, 1, 0.1)  # Subtle white
		zone.size = Vector2(200, 200)  # BattleManager.HITZONE_HEIGHT
		zone.position = lane_positions[i]

		# Add border
		var border = Line2D.new()
		border.width = 3.0
		border.default_color = Color.WHITE
		border.add_point(Vector2(0, 0))
		border.add_point(Vector2(200, 0))
		border.add_point(Vector2(200, 200))
		border.add_point(Vector2(0, 200))
		border.add_point(Vector2(0, 0))
		zone.add_child(border)

		zones.append(zone)

	return zones

func fade_from_black():
	"""Fade in from black overlay."""
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_start_first_step)

func _start_first_step():
	"""Start the first tutorial step."""
	show_tutorial_step(0)

func show_tutorial_step(step_index: int):
	"""Show a tutorial step with highlighted element and text."""
	if step_index >= tutorial_steps.size():
		_transition_to_next_scene()
		return

	var step = tutorial_steps[step_index]

	# Remove previous border
	if current_border:
		current_border.queue_free()
		current_border = null

	# Create flashing border for highlighted element
	match step["highlight"]:
		"groove_bar":
			current_border = create_flashing_border(groove_bar.get_rect(), 10)
		"player_sprite":
			var rect = Rect2(player_sprite.position - Vector2(100, 100), Vector2(200, 200))
			current_border = create_flashing_border(rect, 100)
		"hit_zones":
			# Use existing yellow indicator system
			show_hit_zone_indicators()

	if current_border:
		add_child(current_border)

	# Show title and messages
	var full_text = step["title"] + "\n\n" + "\n".join(step["messages"])
	typewriter.set_text(full_text)

func create_flashing_border(rect: Rect2, padding: float) -> Control:
	"""Create a flashing yellow border around a UI element."""
	var container = Control.new()
	container.position = rect.position - Vector2(padding, padding)
	container.size = rect.size + Vector2(padding * 2, padding * 2)

	# Create border lines
	var border = Line2D.new()
	border.width = 10.0
	border.default_color = Color.YELLOW
	border.z_index = 90

	# Border points
	var w = container.size.x
	var h = container.size.y
	border.add_point(Vector2(0, 0))
	border.add_point(Vector2(w, 0))
	border.add_point(Vector2(w, h))
	border.add_point(Vector2(0, h))
	border.add_point(Vector2(0, 0))

	container.add_child(border)

	# Flashing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(border, "modulate:a", 0.3, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(border, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)

	return container

func show_hit_zone_indicators():
	"""Show yellow indicators on hit zones using BattleManager system."""
	# Use existing BattleManager.create_hit_zone_indicators if available
	# For now, create simple indicators
	for i in range(hit_zones.size()):
		var zone = hit_zones[i]
		var indicator = create_flashing_border(Rect2(zone.position, zone.size), 10)
		add_child(indicator)

func _on_advance_requested():
	"""Handle advance to next tutorial step."""
	if is_transitioning:
		return

	current_step += 1

	if current_step < tutorial_steps.size():
		# Next tutorial step
		show_tutorial_step(current_step)
	else:
		# Tutorial complete, go to calibration
		_transition_to_next_scene()

func _transition_to_next_scene():
	"""Fade to black and load next scene."""
	is_transitioning = true

	# Remove borders
	if current_border:
		current_border.queue_free()

	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(_load_next_scene)

func _load_next_scene():
	"""Load the next scene."""
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_error("TutorialExplanationScene: next_scene_path not set!")
