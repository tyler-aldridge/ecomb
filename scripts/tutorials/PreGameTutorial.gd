extends Node2D

## ============================================================================
## PRE-GAME TUTORIAL
## ============================================================================
## Step-by-step tutorial explaining game mechanics with visual highlights.
## Uses REAL battle UI components (GrooveBar, player sprite, hit zones) with
## centered DialogBox displays (rainbow border, 48px font).
##
## Steps:
## 1. Groove Bar Explanation (yellow border around groove bar)
## 2. XP System Explanation (yellow border around player sprite)
## 3. Hit Zones Explanation (yellow indicators on hit zones)
## 4. Combo System (visual demonstration)
##
## Each step has:
## - Yellow flashing border around relevant UI element
## - Centered DialogBox with rainbow border
## - 5 second auto-advance or player input to skip
## ============================================================================

# Scene configuration
@export var next_scene_path: String = "res://scenes/ui/universal/RhythmCalibration.tscn"
@export var fade_duration: float = 3.0

# Scene references
@onready var player_sprite = $TutorialUI/Player

# UI elements (created dynamically like PreGameBattle)
var ui_layer: CanvasLayer
var groove_bar: Control
var combo_display: Control
var xp_gain_display: Control
var hit_zones: Array = []
var fade_overlay: ColorRect

# Tutorial borders
var current_border: Control
var border_tween: Tween

# State
var current_step: int = 0
var current_message_index: int = 0
var is_transitioning: bool = false

# Tutorial steps data
var tutorial_steps = [
	{
		"messages": [
			"The groove bar on the top shows your rhythm consistency and acts like your health bar.",
			"Perfect timing fills the groove bar. Miss too many beats and it empties.",
			"Don't let it get to zero, or you lose the battle!"
		],
		"highlight": "groove_bar"
	},
	{
		"messages": [
			"Your XP gains will show here over your character.",
			"Perfect hits give maximum XP, good hits give decent XP, okay hits give some XP, and misses give no XP.",
			"Every battle has a maximum XP you can gain. The better your timing, the better your gains!"
		],
		"highlight": "player_sprite",
		"simulate": "xp_gains"
	},
	{
		"messages": [
			"These are the note hit zones. Press 1, 2, or 3 on your keyboard when notes reach the zone in time with the beat!",
			"Perfect hits will line up exactly on center with these areas.",
			"Move to the groove of the song and you'll get some great gains!"
		],
		"highlight": "hit_zones",
		"simulate": "hit_zone_notes"
	},
	{
		"messages": [
			"Chain perfect hits for bonus XP! The longer your combos, the more XP rewards you'll receive.",
			"Break the combo, and you're back to square one. Master the rhythm, master the rewards!",
			"Now let's take a second to calibrate your system with the rhythm of the game..."
		],
		"highlight": "none",
		"simulate": "combo"
	}
]

func _ready():
	setup_battle_ui()
	create_fade_overlay()
	fade_from_black()

func setup_battle_ui():
	"""Create battle UI using REAL components (same as PreGameBattle)."""
	# Create UI layer for proper screen-space rendering
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	# REAL Groove bar (full width at top)
	var groove_bar_scene = preload("res://scenes/ui/battles/GrooveBar.tscn")
	groove_bar = groove_bar_scene.instantiate()
	ui_layer.add_child(groove_bar)

	# Set groove bar to tutorial starting value (50%)
	if groove_bar.has_method("set_groove"):
		groove_bar.set_groove(50.0)

	# Universal character displays (combo below groove bar, XP on player, hit zones)
	# Uses BattleManager's universal setup for consistent positioning
	var displays = BattleManager.setup_battle_character_displays(player_sprite, null, ui_layer)
	combo_display = displays.get("combo_display")
	xp_gain_display = displays.get("xp_display")
	hit_zones = displays.get("hitzones", [])

func create_fade_overlay():
	"""Create black fade overlay for scene transitions."""
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.position = Vector2.ZERO
	fade_overlay.z_index = 1000
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(fade_overlay)

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
	"""Show a tutorial step with highlighted element and centered dialog."""
	if step_index >= tutorial_steps.size():
		_transition_to_next_scene()
		return

	current_step = step_index
	current_message_index = 0
	var step = tutorial_steps[step_index]

	# Remove previous highlighting
	if current_border:
		current_border.queue_free()
		current_border = null

	# Disable groove bar highlighting from previous steps
	if groove_bar and groove_bar.has_method("set_tutorial_highlight"):
		groove_bar.set_tutorial_highlight(false)

	# Enable highlighting for current element
	match step["highlight"]:
		"groove_bar":
			# Use groove bar's built-in border highlighting
			if groove_bar and groove_bar.has_method("set_tutorial_highlight"):
				groove_bar.set_tutorial_highlight(true)
		"player_sprite":
			var rect = Rect2(player_sprite.position - Vector2(100, 100), Vector2(200, 200))
			current_border = create_flashing_border(rect, 15)
		"hit_zones":
			# Create borders for all hit zones
			for zone in hit_zones:
				if zone and is_instance_valid(zone):
					var zone_pos = zone.global_position
					var zone_size = zone.size if zone.has("size") else Vector2(200, 200)
					var border = create_flashing_border(Rect2(zone_pos, zone_size), 15)
					add_child(border)

	if current_border:
		add_child(current_border)

	# Show first message
	show_message(step, 0)

func show_message(step: Dictionary, message_index: int):
	"""Show a single message from the current step."""
	if message_index >= step["messages"].size():
		# Move to next step
		current_step += 1
		if current_step < tutorial_steps.size():
			show_tutorial_step(current_step)
		else:
			_transition_to_next_scene()
		return

	current_message_index = message_index
	var message = step["messages"][message_index]

	# Show centered dialog with rainbow border (48px font, auto-sized)
	# Using "center" character positions dialog in center of screen
	DialogManager.show_dialog(message, "center", 5.0)

	# Run simulation for first message of certain steps
	if message_index == 0 and step.has("simulate"):
		match step["simulate"]:
			"xp_gains":
				_simulate_xp_gains()
			"hit_zone_notes":
				_simulate_hit_zone_notes()
			"combo":
				_simulate_combo()

func create_flashing_border(rect: Rect2, padding: float) -> Control:
	"""Create a flashing yellow border around a UI element."""
	var container = Control.new()
	container.position = rect.position - Vector2(padding, padding)
	container.size = rect.size + Vector2(padding * 2, padding * 2)
	container.z_index = 900

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

func _input(event):
	"""Handle player input to advance tutorial."""
	if is_transitioning:
		return

	if event is InputEventMouseButton and event.pressed:
		_on_advance_requested()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_on_advance_requested()

func _on_advance_requested():
	"""Handle advance to next message or step."""
	if is_transitioning:
		return

	var step = tutorial_steps[current_step]
	current_message_index += 1

	if current_message_index < step["messages"].size():
		# Show next message in current step
		show_message(step, current_message_index)
	else:
		# Move to next step
		current_step += 1
		if current_step < tutorial_steps.size():
			show_tutorial_step(current_step)
		else:
			_transition_to_next_scene()

func _transition_to_next_scene():
	"""Fade to black and load next scene."""
	is_transitioning = true

	# Remove borders and highlighting
	if current_border:
		current_border.queue_free()

	# Disable groove bar highlighting
	if groove_bar and groove_bar.has_method("set_tutorial_highlight"):
		groove_bar.set_tutorial_highlight(false)

	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(_load_next_scene)

func _load_next_scene():
	"""Load the next scene."""
	if next_scene_path != "":
		get_tree().change_scene_to_file(next_scene_path)
	else:
		push_error("PreGameTutorial: next_scene_path not set!")

# ============================================================================
# TUTORIAL SIMULATIONS
# ============================================================================

func _simulate_xp_gains():
	"""Simulate XP gain feedback over player sprite."""
	# Show different quality XP gains in sequence
	await get_tree().create_timer(0.5).timeout
	BattleManager.show_xp_gain(10, "PERFECT", player_sprite.position)

	await get_tree().create_timer(1.2).timeout
	BattleManager.show_xp_gain(7, "GOOD", player_sprite.position)

	await get_tree().create_timer(1.2).timeout
	BattleManager.show_xp_gain(4, "OKAY", player_sprite.position)

func _simulate_hit_zone_notes():
	"""Simulate 6 random half notes hitting perfect center."""
	# Start BattleManager temporarily for simulation
	BattleManager.start_battle({
		"battle_id": "tutorial_simulation",
		"battle_level": 1,
		"battle_type": "tutorial",
		"groove_start": 50.0,
		"groove_miss_penalty": 0.0,
		"max_strength": 100
	})

	# Spawn 6 half notes in random lanes, staggered timing
	for i in range(6):
		await get_tree().create_timer(0.8).timeout

		# Pick random lane (0, 1, or 2)
		var lane = randi() % 3
		var lane_x = hit_zones[lane].global_position.x + 100  # Center of hit zone
		var hitzone_y = hit_zones[lane].global_position.y + 100

		# Spawn note above hit zone
		var note_scene = preload("res://scenes/ui/battles/HalfNote.tscn")
		var note = note_scene.instantiate()
		note.position = Vector2(lane_x, hitzone_y - 400)
		note.z_index = 50
		add_child(note)

		# Animate note falling to perfect center
		var tween = create_tween()
		tween.tween_property(note, "position:y", hitzone_y, 0.6).set_ease(Tween.EASE_IN_OUT)

		# After reaching center, show perfect feedback
		tween.tween_callback(func():
			# Show perfect hit feedback
			BattleManager.process_hit("PERFECT", Vector2(lane_x, hitzone_y))

			# Create shatter effect
			var shatter_tween = BattleManager.create_fade_out_tween(note)
			if shatter_tween:
				await shatter_tween.finished
			note.queue_free()
		)

func _simulate_combo():
	"""Simulate combo display feedback."""
	# Show combo building from the previous hit zone simulation
	# The combo should already be at 6 from the hit zone step
	# Just show the combo display updating
	await get_tree().create_timer(0.5).timeout

	if combo_display and combo_display.has_method("update_combo"):
		combo_display.update_combo(6)
