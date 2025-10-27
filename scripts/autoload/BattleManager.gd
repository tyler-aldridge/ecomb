extends Node

# Universal Rhythm Battle Mechanics: groove, combo, hits, XP, and results

# ============================================================================
# SIGNALS
# ============================================================================

signal groove_changed(current_groove: float, max_groove: float)
signal combo_changed(current_combo: int, multiplier: float)
signal combo_milestone_reached(combo: int, multiplier: float)  # For "10 HIT COMBO!" UI
signal strength_gained(amount: int, total: int)
signal hit_registered(quality: String, strength: int, groove_change: float)
signal battle_failed()  # Groove reached 0%
signal battle_completed(results: Dictionary)  # End of battle results
@warning_ignore("unused_signal")  # Emitted by battle scenes, not BattleManager itself
signal show_groove_tutorial()  # Show groove bar tutorial message
@warning_ignore("unused_signal")  # Emitted by battle scenes, not BattleManager itself
signal hide_groove_tutorial()  # Hide groove bar tutorial message

# ============================================================================
# CONSTANTS - Hit Quality Base Values
# ============================================================================

const HIT_VALUES = {
	"PERFECT": {"strength": 10, "groove": 2.0},
	"GOOD": {"strength": 5, "groove": 1.0},
	"OKAY": {"strength": 1, "groove": 0.5},
	"MISS": {"strength": 0, "groove": 0.0}
}

# Combo thresholds for multiplier increases
const COMBO_THRESHOLDS = {
	0: 1.0,   # 0-9 hits: 1.0x
	10: 1.5,  # 10-19 hits: 1.5x
	20: 2.0,  # 20-29 hits: 2.0x
	30: 2.5,  # 30-39 hits: 2.5x
	40: 3.0   # 40+ hits: 3.0x (max)
}

const MAX_COMBO_MULTIPLIER = 3.0

# Note type configuration: scene, spawn_offset (half-beats before hit time)
const NOTE_TYPE_CONFIG = {
	"whole": {
		"scene": preload("res://scenes/ui/battle/WholeNote.tscn"),
		"spawn_offset": 16
	},
	"half": {
		"scene": preload("res://scenes/ui/battle/HalfNote.tscn"),
		"spawn_offset": 12
	},
	"quarter": {
		"scene": preload("res://scenes/ui/battle/QuarterNote.tscn"),
		"spawn_offset": 12
	}
}

const HITZONE_HEIGHT = 200.0
const HIT_ZONE_POSITIONS = {
	"1": Vector2(610.0, 650.0),
	"2": Vector2(860.0, 650.0),
	"3": Vector2(1110.0, 650.0)
}

const SPAWN_HEIGHT_ABOVE_TARGET = 1000.0
const OVERLAP_PREVENTION_WINDOW = 6
var recent_note_spawns = {}
const MISS_WINDOW = 150.0
const FADE_FROM_BLACK_DURATION = 1.5
const FADE_TO_BLACK_DURATION = 2.0
const BATTLE_START_DELAY = 1.0
const HITZONE_BORDER_WIDTH = 3.0
const HITZONE_BORDER_COLOR = Color.WHITE
const INDICATOR_BORDER_WIDTH = 5.0
const INDICATOR_BORDER_COLOR = Color.YELLOW
const INDICATOR_LABEL_SIZE = 100
const INDICATOR_LABEL_COLOR = Color.YELLOW
const INDICATOR_FADE_DURATION = 0.5
const INDICATOR_PULSE_SCALE = Vector2(1.3, 1.3)
const INDICATOR_PULSE_DURATION = 0.325
const INDICATOR_PULSE_LOOPS = 200
const DIFFICULTY_PRESETS = {
	"wimpy": {"perfect": 0.25, "good": 0.50, "okay": 0.90},
	"casual": {"perfect": 0.20, "good": 0.40, "okay": 0.85},
	"gymbro": {"perfect": 0.125, "good": 0.25, "okay": 0.75},
	"meathead": {"perfect": 0.075, "good": 0.15, "okay": 0.50},
	"gigachad": {"perfect": 0.05, "good": 0.10, "okay": 0.30}
}

# Current difficulty setting (persists across battles)
var current_difficulty: String = "gymbro"

# Current BPM (set by battle scene, used for UI animations)
var current_bpm: float = 120.0

# ============================================================================
# BATTLE STATE
# ============================================================================

var battle_active: bool = false
var battle_id: String = ""
var battle_level: int = 1
var battle_type: String = "story"  # "story", "lesson", or "random"

# Groove bar (health system)
var groove_current: float = 0.0
var groove_max: float = 100.0
var groove_start: float = 50.0
var groove_miss_penalty: float = 10.0  # Per-battle configurable

# Combo system
var combo_current: int = 0
var combo_max: int = 0
var combo_multiplier: float = 1.0

# Hit tracking
var hit_counts = {
	"PERFECT": 0,
	"GOOD": 0,
	"OKAY": 0,
	"MISS": 0
}

# Strength (XP) tracking
var strength_total: int = 0
var strength_max_possible: int = 0  # Maximum strength if all notes hit PERFECT

# ============================================================================
# DIFFICULTY MANAGEMENT
# ============================================================================

func set_difficulty(difficulty: String):
	"""
	Set the hit detection difficulty globally.

	Valid difficulties: "wimpy", "casual", "gymbro", "meathead", "gigachad"
	Called from settings menu or game initialization.
	Persists across all battles until changed.
	"""
	if DIFFICULTY_PRESETS.has(difficulty):
		current_difficulty = difficulty
		print("Hit detection difficulty set to: ", difficulty)
	else:
		push_error("Invalid difficulty: " + difficulty)

func get_difficulty() -> String:
	"""Get the current difficulty setting."""
	return current_difficulty

func get_difficulty_thresholds() -> Dictionary:
	"""Get the current difficulty's hit thresholds (percentages)."""
	return DIFFICULTY_PRESETS[current_difficulty]

# ============================================================================
# BATTLE LIFECYCLE
# ============================================================================

func start_battle(battle_data: Dictionary):
	"""Initialize a new battle with settings from level JSON.

	Args:
		battle_data: Dictionary with keys:
			- battle_id: String (unique identifier for story/lesson battles)
			- battle_level: int (1-10, for XP scaling)
			- battle_type: String ("story", "lesson", or "random")
			- groove_miss_penalty: float (optional, default 10.0)
			- groove_start: float (optional, default 50.0)
			- max_strength: int (optional, max possible strength from all PERFECT hits)
	"""
	battle_active = true
	battle_id = battle_data.get("battle_id", "")
	battle_level = battle_data.get("battle_level", 1)
	battle_type = battle_data.get("battle_type", "story")

	# Groove settings
	groove_start = battle_data.get("groove_start", 50.0)
	groove_miss_penalty = battle_data.get("groove_miss_penalty", 10.0)
	groove_current = groove_start
	groove_max = 100.0

	# Reset tracking
	combo_current = 0
	combo_max = 0
	combo_multiplier = 1.0
	strength_total = 0
	strength_max_possible = battle_data.get("max_strength", 0)
	hit_counts = {"PERFECT": 0, "GOOD": 0, "OKAY": 0, "MISS": 0}
	recent_note_spawns.clear()  # Clear lane overlap tracking from previous battle

	# Emit initial state
	groove_changed.emit(groove_current, groove_max)
	combo_changed.emit(combo_current, combo_multiplier)

func end_battle() -> Dictionary:
	"""End the battle and calculate results.

	Returns:
		Dictionary with battle results:
			- strength_total: int (total XP earned before scaling)
			- strength_awarded: int (actual XP after level scaling)
			- combo_max: int
			- hit_counts: Dictionary
			- battle_completed: bool (true if groove > 0, false if failed)
	"""
	if not battle_active:
		push_warning("BattleManager: end_battle called but no battle is active")
		return {}

	var battle_completed_successfully = groove_current > 0.0

	# Calculate actual XP awarded (with level scaling)
	var strength_awarded = calculate_awarded_strength()

	var results = {
		"battle_id": battle_id,
		"battle_level": battle_level,
		"battle_type": battle_type,
		"strength_total": strength_total,
		"strength_awarded": strength_awarded,
		"strength_max_possible": strength_max_possible,
		"combo_max": combo_max,
		"hit_counts": hit_counts.duplicate(),
		"battle_completed": battle_completed_successfully,
		"groove_final": groove_current
	}

	# Clean up lane overlap tracking
	recent_note_spawns.clear()

	battle_active = false
	battle_completed.emit(results)

	return results

func reset_battle():
	"""Reset all battle state (for restarting after failure)."""
	if battle_active:
		var current_battle_data = {
			"battle_id": battle_id,
			"battle_level": battle_level,
			"battle_type": battle_type,
			"groove_miss_penalty": groove_miss_penalty,
			"groove_start": groove_start
		}
		start_battle(current_battle_data)

# ============================================================================
# HIT PROCESSING
# ============================================================================

func register_hit(quality: String):
	"""Process a hit and update combo, groove, strength.

	Args:
		quality: String - "PERFECT", "GOOD", "OKAY", or "MISS"
	"""
	if not battle_active:
		push_warning("BattleManager: register_hit called but no battle is active")
		return

	# Track hit quality
	if hit_counts.has(quality):
		hit_counts[quality] += 1

	# Handle combo
	if quality == "PERFECT":
		combo_current += 1
		combo_max = max(combo_max, combo_current)
		update_combo_multiplier()
	else:
		# Any non-PERFECT hit resets combo
		combo_current = 0
		combo_multiplier = 1.0
		combo_changed.emit(combo_current, combo_multiplier)

	# Calculate strength gain (with combo multiplier)
	var base_strength = HIT_VALUES[quality]["strength"]
	var strength_gain = int(base_strength * combo_multiplier)
	strength_total += strength_gain

	if strength_gain > 0:
		strength_gained.emit(strength_gain, strength_total)

	# Calculate groove change
	var groove_change = 0.0
	if quality == "MISS":
		groove_change = -groove_miss_penalty
	else:
		# Apply combo multiplier to groove recovery
		var base_groove = HIT_VALUES[quality]["groove"]
		groove_change = base_groove * combo_multiplier

	update_groove(groove_change)

	# Emit hit registered signal
	hit_registered.emit(quality, strength_gain, groove_change)

# ============================================================================
# GROOVE SYSTEM
# ============================================================================

func update_groove(change: float):
	"""Update groove bar and check for battle failure.

	Args:
		change: float - Amount to change groove (positive = gain, negative = loss)
	"""
	groove_current += change
	groove_current = clamp(groove_current, 0.0, groove_max)

	groove_changed.emit(groove_current, groove_max)

	# Check for battle failure
	if groove_current <= 0.0 and battle_active:
		battle_active = false
		battle_failed.emit()

func get_groove_percentage() -> float:
	"""Get current groove as percentage (0.0 to 1.0)."""
	return groove_current / groove_max if groove_max > 0 else 0.0

# ============================================================================
# COMBO SYSTEM
# ============================================================================

func update_combo_multiplier():
	"""Update combo multiplier based on current combo count."""
	var old_multiplier = combo_multiplier

	# Find the highest threshold we've reached
	var new_multiplier = 1.0
	for threshold in COMBO_THRESHOLDS.keys():
		if combo_current >= threshold:
			new_multiplier = COMBO_THRESHOLDS[threshold]

	combo_multiplier = min(new_multiplier, MAX_COMBO_MULTIPLIER)

	combo_changed.emit(combo_current, combo_multiplier)

	# Emit milestone if we crossed a threshold
	if combo_multiplier > old_multiplier:
		combo_milestone_reached.emit(combo_current, combo_multiplier)

func get_combo_multiplier() -> float:
	"""Get current combo multiplier."""
	return combo_multiplier

# ============================================================================
# STRENGTH (XP) CALCULATION
# ============================================================================

func calculate_awarded_strength() -> int:
	"""Calculate actual XP awarded after applying level scaling.

	For story and lesson battles that have been completed before, players can only
	improve on their previous score (tracked in GameManager).

	For random battles, XP is scaled based on player level vs battle level.

	Returns:
		int - Actual XP to award to player
	"""
	var base_strength = strength_total
	var awarded_strength = base_strength

	# Apply level scaling for random battles
	if battle_type == "random":
		awarded_strength = apply_level_scaling(base_strength)

	# Check if this is a replay of a story or lesson battle
	elif (battle_type == "story" or battle_type == "lesson") and battle_id != "":
		awarded_strength = GameManager.calculate_battle_strength_improvement(
			battle_id,
			base_strength
		)

	return awarded_strength

func apply_level_scaling(base_strength: int) -> int:
	"""Apply XP scaling based on player level vs battle level.

	Formula: -10% per level difference, cap at 5 levels (0% XP)

	Examples:
		- Player level 2, Battle level 1: 50% XP
		- Player level 3, Battle level 1: 40% XP
		- Player level 6+, Battle level 1: 0% XP

	Args:
		base_strength: int - Base XP before scaling

	Returns:
		int - Scaled XP
	"""
	var player_level = GameManager.get_player_level()
	var level_difference = player_level - battle_level

	# No penalty if battle is same level or higher
	if level_difference <= 0:
		return base_strength

	# Cap at 5 levels difference
	if level_difference >= 5:
		return 0

	# -10% per level (as decimal: 0.9^level_difference)
	var scale_factor = 1.0 - (level_difference * 0.1)
	return int(base_strength * scale_factor)

# ============================================================================
# GETTERS
# ============================================================================

func is_battle_active() -> bool:
	return battle_active

func get_strength_total() -> int:
	return strength_total

func get_combo_current() -> int:
	return combo_current

func get_combo_max() -> int:
	return combo_max

func get_hit_counts() -> Dictionary:
	return hit_counts.duplicate()

# ============================================================================
# UNIVERSAL BATTLE MECHANICS - Hit Detection & Lane Selection
# ============================================================================

func get_hit_quality_for_note(note: Node, hit_zone_y: float) -> String:
	"""
	Edge-based hit detection: Check how much of the HitZone is COVERED by the note.

	The HitZone is the source of truth. We measure how much of each HitZone edge
	is exposed (not covered by the note) as a PERCENTAGE of HitZone height.
	The WORST exposure determines quality.

	Hit windows (percentage of HitZone height exposed):
	- Perfect: ≤12.5% exposed (e.g., ≤25px for 200px HitZone, ≤12.5px for 100px HitZone)
	- Good: 12.6-25% exposed (e.g., 26-50px for 200px, 13-25px for 100px)
	- Okay: 25.1-75% exposed (e.g., 51-150px for 200px, 26-75px for 100px)
	- Miss: ≥75.1% exposed OR completely outside

	Examples (HitZone 200px):
	- QuarterNote 20px off: 20px/200px = 10% exposed = PERFECT
	- QuarterNote 40px off: 40px/200px = 20% exposed = GOOD
	- WholeNote 40px off: 0px exposed (still fully covered) = PERFECT
	- WholeNote 360px off: 60px/200px = 30% exposed = OKAY
	"""
	# Get note's actual height dynamically
	var note_height = 200.0  # Default
	if note.has_node("NoteTemplate"):
		note_height = note.get_node("NoteTemplate").size.y

	# Calculate edge positions
	var note_top = note.position.y
	var note_bottom = note.position.y + note_height
	var hitzone_top = hit_zone_y
	var hitzone_bottom = hit_zone_y + HITZONE_HEIGHT

	# Check if completely outside (no overlap at all)
	if note_bottom < hitzone_top or note_top > hitzone_bottom:
		return "MISS"

	# Calculate how much of HitZone edges are EXPOSED (not covered by note)
	# If note_top > hitzone_top: HitZone's top edge is exposed
	# If note_bottom < hitzone_bottom: HitZone's bottom edge is exposed
	var top_exposure = max(0.0, note_top - hitzone_top)
	var bottom_exposure = max(0.0, hitzone_bottom - note_bottom)

	# The WORST exposure (largest gap) determines hit quality
	var max_exposure = max(top_exposure, bottom_exposure)

	# Get difficulty thresholds (global settings)
	var difficulty = get_difficulty_thresholds()

	# Calculate thresholds as percentages of HitZone height based on current difficulty
	var perfect_threshold = HITZONE_HEIGHT * difficulty["perfect"]  # e.g., 12.5% of 200px = 25px
	var good_threshold = HITZONE_HEIGHT * difficulty["good"]        # e.g., 25% of 200px = 50px
	var okay_threshold = HITZONE_HEIGHT * difficulty["okay"]        # e.g., 75% of 200px = 150px

	# Determine hit quality based on worst exposure
	if max_exposure <= perfect_threshold:
		return "PERFECT"
	elif max_exposure <= good_threshold:
		return "GOOD"
	elif max_exposure <= okay_threshold:
		return "OKAY"
	else:
		return "MISS"

func choose_lane_avoiding_overlap(current_beat: int) -> String:
	"""Choose a lane that avoids recent spawns to prevent visual overlap."""
	var tracks = ["1", "2", "3"]
	var available_tracks = tracks.duplicate()

	# Remove lanes that have recent spawns within the overlap window
	for beat_pos in recent_note_spawns.keys():
		if abs(current_beat - beat_pos) <= OVERLAP_PREVENTION_WINDOW:
			var used_lane = recent_note_spawns[beat_pos]
			available_tracks.erase(used_lane)

	# If all lanes are blocked, just use any lane
	if available_tracks.size() == 0:
		available_tracks = tracks.duplicate()

	# Choose random from available lanes
	var chosen_lane = available_tracks[randi() % available_tracks.size()]

	# Record this spawn
	recent_note_spawns[current_beat] = chosen_lane

	# Clean up old entries to prevent dict from growing indefinitely
	for beat_pos in recent_note_spawns.keys():
		if abs(current_beat - beat_pos) > OVERLAP_PREVENTION_WINDOW * 2:
			recent_note_spawns.erase(beat_pos)

	return chosen_lane

func create_fade_out_tween(note: Node, _bpm: float) -> Tween:
	"""
	Create a universal fade out tween for hit notes with grid-based shatter effect.

	Notes break apart into a 4x4 grid of pieces that fly outward, creating
	a realistic shattering effect where you can see the note falling apart.

	Args:
		note: The note node to fade
		_bpm: Current song BPM (unused, kept for API compatibility)

	Returns:
		Tween configured for fade animation
	"""
	if not is_instance_valid(note):
		return null

	# Stop the note from moving
	if note.has_method("stop_movement"):
		note.stop_movement()

	# Get note color and size from NoteTemplate
	var note_color = Color.WHITE
	var note_size = Vector2(200, 200)  # Default
	if note.has_node("NoteTemplate"):
		var template = note.get_node("NoteTemplate")
		note_color = template.color
		note_size = template.size

	# Hide the original note immediately
	note.modulate.a = 0.0

	# Get the parent to add shards to (should be the battle scene)
	var parent = note.get_parent()
	if not is_instance_valid(parent):
		note.queue_free()
		return null

	# Create a 3x3 grid of pieces that form the note (reduced from 4x4 for better performance)
	var grid_size = 3
	var piece_size = Vector2(note_size.x / grid_size, note_size.y / grid_size)
	var note_top_left = note.global_position  # Note position is already at top-left
	var explosion_duration = 0.8  # Shatter duration

	for row in range(grid_size):
		for col in range(grid_size):
			var piece = ColorRect.new()
			piece.color = note_color
			piece.size = piece_size

			# Position piece to form the original note shape
			var piece_x = note_top_left.x + (col * piece_size.x)
			var piece_y = note_top_left.y + (row * piece_size.y)
			piece.position = Vector2(piece_x, piece_y)

			parent.add_child(piece)

			# Calculate direction from note center
			var note_center = note_top_left + note_size / 2.0
			var piece_center = piece.position + piece_size / 2.0
			var direction = (piece_center - note_center).normalized()

			# Add some randomness to explosion
			var random_offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
			direction = (direction + random_offset.normalized() * 0.3).normalized()

			# Pieces further from center fly faster
			var distance_from_center = piece_center.distance_to(note_center)
			var speed = 200 + (distance_from_center * 2.0)
			var target_offset = direction * speed

			# Capture piece in local var to avoid lambda capture errors in loop
			var p = piece

			# Create tween on parent (not piece) to avoid lambda capture errors
			var piece_tween = parent.create_tween()
			piece_tween.set_parallel(true)

			# Move outward
			piece_tween.tween_property(p, "position", p.position + target_offset, explosion_duration)

			# Rotate based on position (edge pieces spin more)
			var rotation_amount = randf_range(-PI, PI) * (1.0 + distance_from_center / 100.0)
			piece_tween.tween_property(p, "rotation", rotation_amount, explosion_duration)

			# Fade out
			piece_tween.tween_property(p, "modulate:a", 0.0, explosion_duration)

			# Scale down slightly
			piece_tween.tween_property(p, "scale", Vector2(0.5, 0.5), explosion_duration)

			# Clean up piece after animation - use chain() to avoid lambda issues
			piece_tween.chain().tween_callback(p.queue_free)

	# Clean up original note after a short delay
	var cleanup_tween = parent.create_tween()
	cleanup_tween.tween_callback(note.queue_free).set_delay(explosion_duration)

	return cleanup_tween

func create_miss_fade_tween(note: Node) -> Tween:
	"""
	Create a fast fade out tween for missed notes.

	Missed notes:
	- Turn black
	- Stop in place (no movement)
	- Fade out quickly (0.4 seconds)

	Args:
		note: The note node to fade

	Returns:
		Tween configured for miss animation
	"""
	if not is_instance_valid(note):
		return null

	# Stop the note from moving
	if note.has_method("stop_movement"):
		note.stop_movement()

	# Get parent to create tween on (avoids lambda capture errors)
	var parent = note.get_parent()
	if not is_instance_valid(parent):
		note.queue_free()
		return null

	# Turn note black and fade out fast
	var tween = parent.create_tween()
	tween.set_parallel(true)

	# Turn black immediately
	tween.tween_property(note, "modulate", Color(0, 0, 0, 1), 0.0)

	# Fade out quickly
	tween.tween_property(note, "modulate:a", 0.0, 0.4)

	# Free the note after fade completes (no lambda to avoid capture errors)
	tween.chain().tween_callback(note.queue_free)

	return tween

# ============================================================================
# UNIVERSAL UI SETUP
# ============================================================================

func setup_battle_character_displays(player_sprite: AnimatedSprite2D, opponent_sprite: AnimatedSprite2D, ui_layer: CanvasLayer) -> Dictionary:
	"""
	Universal setup for Combo and XP displays.

	This ensures ALL battles have consistent positioning and behavior for:
	- Combo display (centered between HitZones and bottom edge, 100px font, hidden when 0)
	- XP display (on top of Player sprite, white, 100px font)

	Args:
		player_sprite: The player's AnimatedSprite2D node
		opponent_sprite: The opponent's AnimatedSprite2D node (unused for now)
		ui_layer: The CanvasLayer for UI elements

	Returns:
		Dictionary with keys:
			- combo_display: Label - Combo counter below groove bar
			- xp_display: Label - XP popup on player
	"""
	var displays = {}

	# Combo Display - centered between HitZones and bottom edge
	var combo_display_scene = preload("res://scenes/ui/battle/ComboDisplay.tscn")
	var combo_display = combo_display_scene.instantiate()

	# Add to UI layer (not player sprite)
	ui_layer.add_child(combo_display)

	# Position centered between HitZones (bottom at Y=850) and screen bottom (Y=1080)
	# Center: (850 + 1080) / 2 = 965
	combo_display.anchor_left = 0.5
	combo_display.anchor_top = 0.0
	combo_display.anchor_right = 0.5
	combo_display.anchor_bottom = 0.0
	combo_display.offset_left = -200.0  # Half of 400px width to center
	combo_display.offset_top = 965.0    # Centered between HitZones and bottom
	combo_display.offset_right = 200.0
	combo_display.offset_bottom = 1027.5  # 965 + 62.5 (half of 125px height at 100px font)

	# Start hidden (will show when combo > 0)
	combo_display.visible = false

	displays["combo_display"] = combo_display

	# Hit Zone ColorRects - Universal visual indicators for 3 lanes
	var hitzones = []
	for i in range(3):
		var zone_key = str(i + 1)
		var pos = HIT_ZONE_POSITIONS[zone_key]

		var hitzone = ColorRect.new()
		hitzone.position = pos
		hitzone.size = Vector2(HITZONE_HEIGHT, HITZONE_HEIGHT)  # 200x200
		hitzone.z_index = 100

		# Color by lane (1=red, 2=blue, 3=green)
		match zone_key:
			"1": hitzone.color = Color(1, 0, 0, 1)  # Red
			"2": hitzone.color = Color(0, 0, 1, 1)  # Blue
			"3": hitzone.color = Color(0, 1, 0, 1)  # Green

		ui_layer.add_child(hitzone)
		hitzones.append(hitzone)

	displays["hitzones"] = hitzones

	# XP Gain Display - on top of Player sprite
	if player_sprite:
		var xp_display_scene = preload("res://scenes/ui/battle/XPGainDisplay.tscn")
		var xp_display = xp_display_scene.instantiate()

		# Attach as child so it follows player (including jumps)
		player_sprite.add_child(xp_display)

		# For Control nodes parented to Node2D, we use custom_minimum_size and set position
		# Position is relative to parent (player sprite center at 0,0)
		xp_display.position = Vector2(-150, -170)  # Adjusted: -half width for centering, -170 for height above sprite

		# Reset anchors to 0 (not used when parented to Node2D)
		xp_display.anchor_left = 0.0
		xp_display.anchor_top = 0.0
		xp_display.anchor_right = 0.0
		xp_display.anchor_bottom = 0.0

		# Set explicit size (300x40 for centered 100pt font XP text)
		xp_display.custom_minimum_size = Vector2(300, 40)
		xp_display.size = Vector2(300, 40)

		# Pivot at center of the 300x40 box for scaling
		xp_display.pivot_offset = Vector2(150, 20)

		displays["xp_display"] = xp_display

	# Apply opponent visual effect (color invert shader)
	if opponent_sprite:
		apply_opponent_shader(opponent_sprite)

	# Sprite positioning is now handled manually in each battle scene
	# This allows for better control of sprite placement per-battle

	return displays

func get_note_height(note: Node) -> float:
	"""
	Universal helper to get note height dynamically.
	Works for all note types by checking for NoteTemplate child.

	Args:
		note: The note node to get height for

	Returns:
		float: The note's height in pixels (defaults to 200.0 if not found)
	"""
	if note.has_node("NoteTemplate"):
		return note.get_node("NoteTemplate").size.y
	return 200.0  # Default fallback

func create_hit_zone_indicators(ui_layer: CanvasLayer, tween_parent: Node) -> Array:
	"""
	Universal function to create yellow tutorial indicators (borders and numbers) on all hit zones.
	Displays lane numbers with pulsing animation and yellow borders.
	Scales automatically with HIT_ZONE_POSITIONS - works for 3, 4, 5+ lanes.

	Args:
		ui_layer: The CanvasLayer to add indicator nodes to
		tween_parent: The node to create tweens on (prevents lambda capture errors)

	Returns:
		Array of indicator nodes (borders and labels) that can be cleaned up later
	"""
	var indicator_nodes = []

	# Show groove bar tutorial message
	show_groove_tutorial.emit()

	# Create indicators for each lane dynamically
	for lane_key in HIT_ZONE_POSITIONS.keys():
		var pos = HIT_ZONE_POSITIONS[lane_key]

		# Create yellow border
		var border = Line2D.new()
		border.width = INDICATOR_BORDER_WIDTH
		border.default_color = INDICATOR_BORDER_COLOR
		border.modulate.a = 0.0  # Start invisible for fade in
		border.add_point(Vector2(0, 0))
		border.add_point(Vector2(HITZONE_HEIGHT, 0))
		border.add_point(Vector2(HITZONE_HEIGHT, HITZONE_HEIGHT))
		border.add_point(Vector2(0, HITZONE_HEIGHT))
		border.add_point(Vector2(0, 0))
		border.position = pos
		border.z_index = 350
		ui_layer.add_child(border)
		indicator_nodes.append(border)

		# Fade in border
		var border_fade_tween = tween_parent.create_tween()
		border_fade_tween.tween_property(border, "modulate:a", 1.0, INDICATOR_FADE_DURATION)

		# Create lane number label
		var label = Label.new()
		label.text = lane_key
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", INDICATOR_LABEL_SIZE)
		label.add_theme_color_override("font_color", INDICATOR_LABEL_COLOR)
		label.position = pos + Vector2(50, 50)
		label.size = Vector2(100, 100)
		label.pivot_offset = Vector2(50, 50)  # Scale from center
		label.modulate.a = 0.0  # Start invisible for fade in
		label.z_index = 350
		ui_layer.add_child(label)
		indicator_nodes.append(label)

		# Fade in label
		var fade_tween = tween_parent.create_tween()
		fade_tween.tween_property(label, "modulate:a", 1.0, INDICATOR_FADE_DURATION)

		# Pulsing scale animation
		var scale_tween = tween_parent.create_tween()
		scale_tween.set_loops(INDICATOR_PULSE_LOOPS)
		scale_tween.tween_property(label, "scale", INDICATOR_PULSE_SCALE, INDICATOR_PULSE_DURATION)
		scale_tween.tween_property(label, "scale", Vector2(1.0, 1.0), INDICATOR_PULSE_DURATION)

	return indicator_nodes

func stop_hit_zone_indicators(indicator_nodes: Array, tween_parent: Node):
	"""
	Universal function to fade out and remove all hit zone indicator nodes.

	Args:
		indicator_nodes: Array of indicator nodes (borders and labels) to remove
		tween_parent: The node to create fade tweens on
	"""
	# Hide groove bar tutorial message
	hide_groove_tutorial.emit()

	for indicator in indicator_nodes:
		if is_instance_valid(indicator):
			var fade_out_tween = tween_parent.create_tween()
			fade_out_tween.tween_property(indicator, "modulate:a", 0.0, INDICATOR_FADE_DURATION)
			# Pass queue_free directly to avoid lambda capture errors
			fade_out_tween.tween_callback(indicator.queue_free)

func apply_opponent_shader(opponent_sprite: AnimatedSprite2D):
	"""
	Apply visual effect to opponent sprite.

	Currently applies color invert shader to make opponent visually distinct.
	This is a universal function that all battles should use for consistency.

	Args:
		opponent_sprite: The opponent's AnimatedSprite2D node
	"""
	if not opponent_sprite:
		return

	var invert_shader = load("res://assets/shaders/color_invert.gdshader")
	if invert_shader:
		var invert_material = ShaderMaterial.new()
		invert_material.shader = invert_shader
		opponent_sprite.material = invert_material
# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func clamp_to_screen(element_pos: Vector2, element_size: Vector2, margin: float = 50.0) -> Vector2:
	"""Clamp a position to keep an element visible on screen.

	Args:
		element_pos: Top-left position of the element
		element_size: Size of the element (width, height)
		margin: Minimum margin from screen edge in pixels

	Returns:
		Clamped position that keeps the element visible
	"""
	var viewport_size = get_viewport().get_visible_rect().size

	var clamped_x = clamp(element_pos.x, margin, viewport_size.x - element_size.x - margin)
	var clamped_y = clamp(element_pos.y, margin, viewport_size.y - element_size.y - margin)

	return Vector2(clamped_x, clamped_y)

# ============================================================================
# FEEDBACK TEXT SYSTEM
# ============================================================================

func get_random_feedback_text(quality: String) -> String:
	"""Get random encouraging/fail text for hit quality.

	Args:
		quality: "PERFECT", "GOOD", "OKAY", or "MISS"

	Returns:
		Random feedback text string
	"""
	match quality:
		"PERFECT":
			var perfect_texts = ["Perfect!", "Wow!", "Super!", "Amazing!", "Awesome!"]
			return perfect_texts[randi() % perfect_texts.size()]
		"GOOD":
			var good_texts = ["Nice!", "Good!", "Decent!", "Alright!", "Not bad!"]
			return good_texts[randi() % good_texts.size()]
		"OKAY":
			var okay_texts = ["Almost!", "Close!", "Not quite!", "Barely!", "Off beat!"]
			return okay_texts[randi() % okay_texts.size()]
		"MISS":
			var miss_texts = ["Missed!", "Oops!", "Miss!", "Nope!", "Fail!"]
			return miss_texts[randi() % miss_texts.size()]
		_:
			return "?"

# ============================================================================
# TRACK COLOR SYSTEM
# ============================================================================

func get_track_color(track_key: String) -> String:
	"""Get universal color scheme for note lanes.

	Args:
		track_key: "1", "2", or "3"

	Returns:
		Color string: "cyan", "magenta", "yellow", or "white"
	"""
	match track_key:
		"1": return "cyan"
		"2": return "magenta"
		"3": return "yellow"
		_: return "white"

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func explode_note_at_position(note: Node, color_type: String, intensity: int, explosion_pos: Vector2, effects_layer: Node2D, scene_root: Node):
	"""Create particle explosion effect at note position.

	Universal explosion system for all battles with different color schemes:
	- Rainbow: PERFECT hits (starts with note color, transitions to rainbow)
	- Cyan/Magenta/Yellow: Track-colored hits
	- Black/Gray: MISS

	Args:
		note: The note node (used to get note color for PERFECT transitions)
		color_type: "rainbow", "cyan", "magenta", "yellow", "white", or "black"
		intensity: Explosion strength (1-5), affects particle count
		explosion_pos: Center position for explosion
		effects_layer: Node2D to add particles to
		scene_root: Root node for create_tween()
	"""
	# Only clamp MISS explosions to screen bounds (keep others at actual note position)
	var note_center = explosion_pos
	if color_type == "black":
		var viewport_size = get_viewport().get_visible_rect().size
		note_center = Vector2(
			clamp(explosion_pos.x, 100, viewport_size.x - 100),
			clamp(explosion_pos.y, 100, viewport_size.y - 100)
		)

	# Get note's original color for PERFECT transitions
	var note_color = Color.WHITE
	if color_type == "rainbow" and is_instance_valid(note) and note.has_node("NoteTemplate"):
		note_color = note.get_node("NoteTemplate").color

	# Reduce particle count for HTML5 performance (was intensity * 20)
	var particle_count = intensity * 12

	for i in range(particle_count):
		var particle = ColorRect.new()
		var particle_size = randi_range(8, 25)
		particle.size = Vector2(particle_size, particle_size)
		particle.pivot_offset = particle.size / 2

		var target_color = Color.WHITE
		match color_type:
			"rainbow":
				# Start with note's color
				particle.color = note_color
				# Pick a rainbow color to transition to
				var rainbow_colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.PURPLE, Color.MAGENTA, Color.PINK]
				target_color = rainbow_colors[i % rainbow_colors.size()]
			"cyan":
				var cyan_shades = [Color.CYAN, Color.LIGHT_CYAN, Color.AQUA, Color.TURQUOISE]
				particle.color = cyan_shades[i % cyan_shades.size()]
			"magenta":
				var magenta_shades = [Color.MAGENTA, Color.DEEP_PINK, Color.HOT_PINK, Color.VIOLET]
				particle.color = magenta_shades[i % magenta_shades.size()]
			"yellow":
				var yellow_shades = [Color.YELLOW, Color.GOLD, Color.ORANGE, Color.LIGHT_YELLOW]
				particle.color = yellow_shades[i % yellow_shades.size()]
			"white":
				particle.color = Color.WHITE
			"black":
				var dark_colors = [Color.BLACK, Color.DIM_GRAY, Color.DARK_GRAY, Color.PURPLE]
				particle.color = dark_colors[i % dark_colors.size()]

		particle.rotation = randf() * TAU
		particle.position = note_center + Vector2(randi_range(-40, 40), randi_range(-40, 40))

		# For PERFECT hits, start particles slightly larger to show the color transition better
		if color_type == "rainbow":
			particle.scale = Vector2(1.5, 1.5)

		effects_layer.add_child(particle)

		var tween = scene_root.create_tween()
		tween.set_parallel(true)

		var explosion_radius = 600 if color_type == "rainbow" else 450
		var random_direction = Vector2(randf_range(-explosion_radius, explosion_radius), randf_range(-explosion_radius, explosion_radius))
		var duration = randf_range(0.7, 1.1)

		tween.tween_property(particle, "position", particle.position + random_direction, duration)
		tween.tween_property(particle, "rotation", particle.rotation + randf_range(-TAU * 2, TAU * 2), duration)

		if color_type == "rainbow":
			tween.tween_property(particle, "modulate:a", 0.0, duration * 0.6).set_delay(duration * 0.4)
			tween.tween_property(particle, "color", target_color, duration * 0.6)
		else:
			tween.tween_property(particle, "modulate:a", 0.0, duration)

		tween.tween_property(particle, "scale", Vector2(3.0, 3.0), duration * 0.2)
		tween.tween_property(particle, "scale", Vector2(0.0, 0.0), duration * 0.8).set_delay(duration * 0.2)

		# Clean up particle - use chain() to avoid lambda capture errors
		tween.chain().tween_callback(particle.queue_free)

func show_feedback_at_position(text: String, note_pos: Vector2, flash_screen: bool, effects_layer: Node2D, scene_root: Node):
	"""Show floating feedback text at note position.

	Universal feedback display for all battles:
	- Floats up 80px over 0.8s
	- Fades out over 1.0s
	- Optional red screen flash on MISS

	Args:
		text: Feedback text to display (e.g., "Perfect!", "Missed!")
		note_pos: Center position of the note
		flash_screen: If true, flash screen red (for MISS)
		effects_layer: Node2D to add label to
		scene_root: Root node for create_tween() and modulate access
	"""
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.z_index = 300

	# note_pos passed in is the NOTE CENTER already
	var note_center = note_pos
	var desired_position = Vector2(note_center.x - 200, note_center.y - 100)
	var label_size = Vector2(400, 200)

	# Clamp to screen so feedback is always visible
	label.position = clamp_to_screen(desired_position, label_size)
	label.size = label_size
	effects_layer.add_child(label)

	if flash_screen:
		scene_root.modulate = Color.RED
		var flash_tween = scene_root.create_tween()
		flash_tween.tween_property(scene_root, "modulate", Color.WHITE, 0.2)

	# ALL feedback moves up and fades identically at the same rate
	var move_tween = scene_root.create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(label, "position:y", label.position.y - 80, 0.8)
	move_tween.tween_property(label, "modulate:a", 0.0, 1.0)
	# Clean up label (no lambda to avoid capture errors)
	move_tween.tween_callback(label.queue_free).set_delay(1.0)

# ============================================================================
# CHARACTER ANIMATIONS
# ============================================================================

# Animation pools - Add new animations here to randomly select from
# Special keyword: "jump" triggers programmatic jump tween (not a SpriteFrames animation)
const PLAYER_PERFECT_ANIMATIONS = ["pecs", "jump"]  # Add more: ["flex", "dance", "celebrate"]
const PLAYER_GOOD_ANIMATIONS = []                    # Add if desired: ["nod", "thumbsup"]
const PLAYER_OKAY_ANIMATIONS = []                    # Add if desired: ["shrug"]
const OPPONENT_MISS_ANIMATIONS = ["jump"]            # Add more: ["laugh", "taunt", "celebrate"]

func animate_player_hit(player_sprite: AnimatedSprite2D, player_original_pos: Vector2, quality: String, scene_root: Node):
	"""Animate player character on successful hit.

	Universal player animations with random selection:
	- PERFECT: Randomly picks from PLAYER_PERFECT_ANIMATIONS
	- GOOD: Randomly picks from PLAYER_GOOD_ANIMATIONS (optional)
	- OKAY: Randomly picks from PLAYER_OKAY_ANIMATIONS (optional)

	Special "jump" keyword: Triggers jump tween instead of SpriteFrames animation

	Args:
		player_sprite: Player's AnimatedSprite2D
		player_original_pos: Player's original Y position for jump
		quality: Hit quality ("PERFECT", "GOOD", "OKAY")
		scene_root: Root node for create_tween()
	"""
	if not player_sprite:
		return

	var animation_pool = []

	match quality:
		"PERFECT":
			animation_pool = PLAYER_PERFECT_ANIMATIONS
		"GOOD":
			animation_pool = PLAYER_GOOD_ANIMATIONS
		"OKAY":
			animation_pool = PLAYER_OKAY_ANIMATIONS

	# Play random animation from pool if available
	if animation_pool.size() > 0:
		# Randomly select an animation from the pool
		var random_animation = animation_pool[randi() % animation_pool.size()]

		# Special case: "jump" is a programmatic tween, not a SpriteFrames animation
		if random_animation == "jump":
			_execute_jump_animation(player_sprite, player_original_pos, scene_root)
		# Regular SpriteFrames animation
		elif player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation(random_animation):
			player_sprite.play(random_animation)

			# Disconnect all existing animation_finished connections to avoid "already connected" errors
			# This is safe because we're using ONE_SHOT connections
			for connection in player_sprite.animation_finished.get_connections():
				player_sprite.animation_finished.disconnect(connection["callable"])

			# Connect one-shot to return to idle (use bind to avoid lambda capture)
			if player_sprite.sprite_frames.has_animation("idle"):
				player_sprite.animation_finished.connect(
					player_sprite.play.bind("idle"),
					CONNECT_ONE_SHOT
				)


func _execute_jump_animation(sprite: AnimatedSprite2D, original_pos: Vector2, scene_root: Node):
	"""Execute universal jump tween animation.

	Programmatic jump animation that works for both Player and Opponent:
	- Jumps 60px up over 0.25s
	- Falls back down over 0.25s
	- Returns to idle animation after jump completes

	Args:
		sprite: The AnimatedSprite2D to jump
		original_pos: Original Y position to return to
		scene_root: Root node for create_tween()
	"""
	if not sprite:
		return

	var tween = scene_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", original_pos.y - 60, 0.25)
	tween.tween_property(sprite, "position:y", original_pos.y, 0.25).set_delay(0.25)

	# Return to idle after jump completes
	# Note: Sprite persists throughout battle, but we check animation exists before creating callback
	# to avoid any potential issues
	tween.chain()
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		# Use bind to pass argument without lambda capture
		tween.tween_callback(sprite.play.bind("idle"))

func animate_opponent_miss(opponent_sprite: AnimatedSprite2D, opponent_original_pos: Vector2, scene_root: Node):
	"""Animate opponent character on player MISS.

	Universal opponent animation with random selection:
	- Randomly picks from OPPONENT_MISS_ANIMATIONS
	- Returns to idle after animation finishes

	Special "jump" keyword: Triggers jump tween instead of SpriteFrames animation

	Args:
		opponent_sprite: Opponent's AnimatedSprite2D
		opponent_original_pos: Opponent's original Y position for jump
		scene_root: Root node for create_tween()
	"""
	if not opponent_sprite:
		return

	# Play random animation from pool if available
	if OPPONENT_MISS_ANIMATIONS.size() > 0:
		# Randomly select an animation from the pool
		var random_animation = OPPONENT_MISS_ANIMATIONS[randi() % OPPONENT_MISS_ANIMATIONS.size()]

		# Special case: "jump" is a programmatic tween, not a SpriteFrames animation
		if random_animation == "jump":
			_execute_jump_animation(opponent_sprite, opponent_original_pos, scene_root)
		# Regular SpriteFrames animation
		elif opponent_sprite.sprite_frames and opponent_sprite.sprite_frames.has_animation(random_animation):
			opponent_sprite.play(random_animation)

			# Disconnect all existing animation_finished connections to avoid "already connected" errors
			# This is safe because we're using ONE_SHOT connections
			for connection in opponent_sprite.animation_finished.get_connections():
				opponent_sprite.animation_finished.disconnect(connection["callable"])

			# Connect one-shot to return to idle (use bind to avoid lambda capture)
			if opponent_sprite.sprite_frames.has_animation("idle"):
				opponent_sprite.animation_finished.connect(
					opponent_sprite.play.bind("idle"),
					CONNECT_ONE_SHOT
				)
