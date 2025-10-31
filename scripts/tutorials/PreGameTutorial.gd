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

# Tutorial borders
var current_border: Control
var border_tween: Tween
var hit_zone_indicators: Array = []  # Track hit zone indicators for cleanup

# State
var current_step: int = 0
var current_message_index: int = 0
var is_transitioning: bool = false
var auto_advance_timer: SceneTreeTimer = null
var xp_simulation_active: bool = false  # Track if XP simulation should continue
var note_spawning_active: bool = false  # Track if note spawning should continue

# Tutorial steps data
var tutorial_steps = [
	{
		"messages": [
			"The groove bar on the top acts as your health while in rhythm battles.",
			"Perfect timing fills the groove bar. Missing beats drains it. Slightly off beat hits have no effect.",
			"Always keep an eye on your groove bar. If it reaches zero, you lose the battle!"
		],
		"highlight": "groove_bar"
	},
	{
		"messages": [
			"Your XP gains appear above your character during each battle.",
			"Perfect hits give maximum XP. Good hits give decent XP. Okay hits give some XP. Misses give nothing.",
			"Each battle has maximum XP available. Better timing means better gains!"
		],
		"highlight": "player_sprite",
		"simulate": "xp_gains"
	},
	{
		"messages": [
			"These are the note hit zones. Press 1, 2, or 3 when notes reach the center of the zone in time with the beat.",
			"Perfect hits line up exactly with the center of these zones.",
			"Feel the groove and nail the timing to outflex your opponent!"
		],
		"highlight": "hit_zones",
		"simulate": "hit_zone_notes"
	},
	{
		"messages": [
			"Chain perfect hits for bonus XP! Longer combos give bigger rewards.",
			"Break the combo and you start over. Master the rhythm, master the rewards.",
			"Now that you know the basics, let's calibrate your system with the game's rhythm..."
		],
		"highlight": "none",
		"simulate": "combo"
	}
]

func _ready():
	# Set background to pure black
	var background = $TutorialUI/Background
	if background and background is ColorRect:
		background.color = Color.BLACK
		background.visible = true

	# Setup battle UI components
	# Router handles scene fade, so we start directly
	setup_battle_ui()

	# Wait for Router fade-in to complete before showing dialog
	# Router fade is 3 seconds, reduced buffer
	await get_tree().create_timer(2.0).timeout

	# Start first tutorial step
	_start_first_step()

func setup_battle_ui():
	"""Create battle UI using REAL components (same as PreGameBattle)."""
	# Start player sprite invisible for smooth fade-in
	player_sprite.modulate.a = 0.0

	# Create UI layer for proper screen-space rendering
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 100
	add_child(ui_layer)

	# REAL Groove bar (full width at top)
	var groove_bar_scene = preload("res://scenes/ui/battles/GrooveBar.tscn")
	groove_bar = groove_bar_scene.instantiate()

	# Start invisible for smooth fade-in with scene
	groove_bar.modulate.a = 0.0

	ui_layer.add_child(groove_bar)

	# Fade in the groove bar (longer duration, no delay)
	var groove_fade = create_tween()
	groove_fade.tween_property(groove_bar, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_OUT).set_delay(0.5)

	# Fade in the player sprite (longer duration, no delay)
	var sprite_fade = create_tween()
	sprite_fade.tween_property(player_sprite, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_OUT).set_delay(0.5)

	# Set groove bar to tutorial starting value (50%)
	if groove_bar.has_method("set_groove"):
		groove_bar.set_groove(50.0)

	# Universal character displays (combo below groove bar, XP on player, hit zones)
	# Uses BattleManager's universal setup for consistent positioning
	var displays = BattleManager.setup_battle_character_displays(player_sprite, null, ui_layer)
	combo_display = displays.get("combo_display")
	xp_gain_display = displays.get("xp_display")
	hit_zones = displays.get("hitzones", [])

	# Fade in hit zones (longer duration, visible fade)
	for zone in hit_zones:
		if zone and is_instance_valid(zone):
			zone.modulate.a = 0.0
			var zone_fade = create_tween()
			zone_fade.tween_property(zone, "modulate:a", 1.0, 1.5).set_ease(Tween.EASE_OUT).set_delay(0.5)

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

	# Stop any active simulations when changing steps
	xp_simulation_active = false
	# Note: note_spawning_active continues from hit zone to combo section

	# Hide XP gain display when not on XP step (step 1)
	if xp_gain_display:
		xp_gain_display.visible = (step_index == 1)

	# Remove previous highlighting
	if current_border:
		current_border.queue_free()
		current_border = null

	# Remove hit zone indicators from previous step
	if hit_zone_indicators.size() > 0:
		BattleManager.stop_hit_zone_indicators(hit_zone_indicators, self)
		hit_zone_indicators.clear()

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
			# Create yellow border around player sprite extending vertically
			# Top: 175px above sprite (reduced by 25px), Bottom: raised 25px total from screen
			var sprite_top = player_sprite.global_position.y - 175  # Reduced from -200
			var sprite_bottom = 1055  # Raised 25px total from screen height (1080)
			var border_height = sprite_bottom - sprite_top
			var rect = Rect2(
				player_sprite.global_position.x - 125,  # Center horizontally around sprite
				sprite_top,
				250,  # Width
				border_height
			)
			current_border = create_flashing_border(rect, 20)
		"hit_zones":
			# Create keyboard indicators (1, 2, 3) with yellow flashing borders
			hit_zone_indicators = BattleManager.create_hit_zone_indicators(ui_layer, self, ["1", "2", "3"])
		"none":
			# Combo section - create flashing border around combo display
			# 50px left/right padding, 25px top/bottom padding
			if step.has("simulate") and step["simulate"] == "combo":
				if combo_display:
					var combo_pos = combo_display.global_position
					var combo_size = combo_display.size
					# Manually apply different padding: 50px horizontal, 25px vertical
					var rect = Rect2(
						combo_pos.x - 50,  # Left padding
						combo_pos.y - 25,  # Top padding
						combo_size.x + 100,  # Width + left/right padding
						combo_size.y + 50   # Height + top/bottom padding
					)
					current_border = create_flashing_border(rect, 0)  # No additional padding

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

	# Run simulation IMMEDIATELY for first message of certain steps
	if message_index == 0 and step.has("simulate"):
		match step["simulate"]:
			"xp_gains":
				_simulate_xp_gains()
			"hit_zone_notes":
				_simulate_hit_zone_notes()
			"combo":
				_simulate_combo()

	# Show centered dialog with rainbow border (48px font, auto-sized)
	# Using "center" character positions dialog in center of screen
	# AWAIT the typing to complete, then pause 3 seconds
	await DialogManager.show_dialog(message, "center", 0.0)

	# Pause for 3.5 seconds after typing finishes before advancing to next message
	auto_advance_timer = get_tree().create_timer(3.5)
	await auto_advance_timer.timeout

	# Only advance if we're still on the same message (not manually advanced)
	if not is_transitioning and current_message_index == message_index:
		_on_advance_requested()
	auto_advance_timer = null

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

	# Start invisible for fade-in
	border.modulate.a = 0.0

	# Border points
	var w = container.size.x
	var h = container.size.y
	border.add_point(Vector2(0, 0))
	border.add_point(Vector2(w, 0))
	border.add_point(Vector2(w, h))
	border.add_point(Vector2(0, h))
	border.add_point(Vector2(0, 0))

	container.add_child(border)

	# Fade in, then flash
	var fade_tween = create_tween()
	fade_tween.tween_property(border, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# Flashing animation (large number of loops instead of infinite to avoid errors)
	var tween = create_tween()
	tween.set_loops(1000)
	tween.tween_property(border, "modulate:a", 0.3, 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(border, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_IN_OUT)

	return container

func _input(event):
	"""Handle player input to skip typing and advance tutorial."""
	if is_transitioning:
		return

	# ESC key skips entire tutorial
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		# Stop dialog typing immediately
		get_tree().root.set_meta("skip_dialog_typing", true)
		_transition_to_next_scene()
		return

	# Allow click or spacebar to skip typing and advance to next message
	if event is InputEventMouseButton and event.pressed:
		# Set skip flag for DialogManager to skip typing
		get_tree().root.set_meta("skip_dialog_typing", true)
		# Advance to next message
		_on_advance_requested()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# Set skip flag for DialogManager to skip typing
		get_tree().root.set_meta("skip_dialog_typing", true)
		# Advance to next message
		_on_advance_requested()

func _on_advance_requested():
	"""Handle advance to next message or step."""
	if is_transitioning:
		return

	# Cancel auto-advance timer if manually advancing
	if auto_advance_timer:
		# Timer is already running, will be cancelled naturally
		pass

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
	"""Fade to black and load next scene using Router."""
	is_transitioning = true

	# Stop all active simulations
	xp_simulation_active = false
	note_spawning_active = false

	# Remove borders and highlighting
	if current_border:
		current_border.queue_free()

	# Remove hit zone indicators
	if hit_zone_indicators.size() > 0:
		BattleManager.stop_hit_zone_indicators(hit_zone_indicators, self)
		hit_zone_indicators.clear()

	# Disable groove bar highlighting
	if groove_bar and groove_bar.has_method("set_tutorial_highlight"):
		groove_bar.set_tutorial_highlight(false)

	# Use Router for scene transition with fade
	if next_scene_path != "":
		Router.goto_scene_with_fade(next_scene_path, fade_duration)
	else:
		push_error("PreGameTutorial: next_scene_path not set!")

func _load_next_scene():
	"""Deprecated - now using Router.goto_scene_with_fade()."""
	pass

# ============================================================================
# TUTORIAL SIMULATIONS
# ============================================================================

func _simulate_xp_gains():
	"""Simulate XP gain feedback over player sprite continuously."""
	# Enable continuous XP simulation
	xp_simulation_active = true

	# XP quality types to cycle through
	var xp_types = [
		{"quality": "PERFECT", "xp": 10, "multiplier": 5.0},
		{"quality": "GOOD", "xp": 7, "multiplier": 3.0},
		{"quality": "OKAY", "xp": 4, "multiplier": 1.0}
	]
	var type_index = 0

	# Initial delay before starting
	await get_tree().create_timer(0.5).timeout

	# Loop continuously while on XP step
	while xp_simulation_active:
		# Check flag before emitting (in case we just stopped)
		if not xp_simulation_active:
			break

		var xp_data = xp_types[type_index]
		BattleManager.hit_registered.emit(xp_data["quality"], xp_data["xp"], xp_data["multiplier"])

		# Move to next XP type (cycle through PERFECT → GOOD → OKAY → repeat)
		type_index = (type_index + 1) % xp_types.size()

		# Wait before next XP gain
		await get_tree().create_timer(1.2).timeout

func _simulate_hit_zone_notes():
	"""Start continuous note spawning - hides combo display."""
	# Hide combo display during this section
	if combo_display:
		combo_display.visible = false

	# Initialize BattleManager for combo/groove tracking
	BattleManager.start_battle({
		"battle_id": "tutorial_simulation",
		"battle_level": 1,
		"battle_type": "lesson",
		"groove_start": 50.0,
		"groove_miss_penalty": 0.0,
		"max_strength": 100
	})

	# Start continuous note spawning
	note_spawning_active = true
	_spawn_notes_continuously()

func _simulate_combo():
	"""Show combo display - note spawning continues from previous section."""
	# Show combo display for this section
	await get_tree().create_timer(0.5).timeout
	if combo_display:
		combo_display.visible = true

func _spawn_notes_continuously():
	"""Continuously spawn notes in random lanes until stopped."""
	while note_spawning_active:
		# Pick random lane (0, 1, or 2) and convert to lane key
		var lane_index = randi() % 3
		var lane_key = str(lane_index + 1)

		# Get hit zone position from BattleManager constants
		var hit_zone_pos = BattleManager.HIT_ZONE_POSITIONS[lane_key]

		# Half notes are 200x400 (width x height), Hit zones are 200x200
		# For dead center: note center aligns with hit zone center
		# Note center Y = note.position.y + 200 (half of 400px)
		# Hit zone center Y = hit_zone_pos.y + 100 (half of 200px)
		# So: note.position.y + 200 = hit_zone_pos.y + 100
		# Therefore: note.position.y = hit_zone_pos.y - 100
		# This means 100px extends above hit zone, 200px aligns, 100px extends below
		var note_x = hit_zone_pos.x  # Align left edges (both 200px wide)
		var note_target_y = hit_zone_pos.y - 100  # Center note on hit zone
		var hitzone_center_y = hit_zone_pos.y + 100  # Hit zone center for effects
		var note_center_x = hit_zone_pos.x + 100  # Note center X for effects

		# Use the proper note scene from BattleManager
		var note_scene = BattleManager.NOTE_TYPE_CONFIG["half"]["scene"]
		var note = note_scene.instantiate()

		# Get NoteTemplate to set color BEFORE adding to scene
		if note.has_node("NoteTemplate"):
			var template = note.get_node("NoteTemplate")
			# Set CMY colors based on lane
			match lane_key:
				"1":
					template.color = Color.CYAN
				"2":
					template.color = Color.MAGENTA
				"3":
					template.color = Color.YELLOW

		# Position note off-screen above, aligned with hit zone
		note.position = Vector2(note_x, -600)  # Start off-screen
		note.z_index = 50  # Below dialogs (which are z_index 1000)
		add_child(note)

		# Animate note falling to perfect center (2.0s for smooth, slower fall)
		var tween = create_tween()
		tween.tween_property(note, "position:y", note_target_y, 2.0).set_ease(Tween.EASE_IN)

		# After reaching center, show perfect feedback and explosion
		# Note: Don't await inside the callback - let shatter happen asynchronously
		tween.tween_callback(func():
			if not is_instance_valid(note):
				return

			var effect_pos = Vector2(note_center_x, hitzone_center_y)

			# Register the hit with BattleManager (updates combo, groove)
			BattleManager.register_hit("PERFECT")

			# Keep combo display hidden during hit zone section
			if current_step == 2 and combo_display:  # Step 2 is hit zones
				combo_display.visible = false

			# Show random feedback text
			var feedback_text = BattleManager.get_random_feedback_text("PERFECT")
			BattleManager.show_feedback_at_position(feedback_text, effect_pos, false, self, self)

			# Perfect hit: rainbow explosion
			BattleManager.explode_note_at_position(note, "rainbow", 5, effect_pos, self, self)

			# Create shatter effect and free note asynchronously (don't await!)
			BattleManager.create_fade_out_tween(note, 120.0)
		)

		# Wait before spawning next note (1.2s for smooth flow without bunching)
		await get_tree().create_timer(1.2).timeout
