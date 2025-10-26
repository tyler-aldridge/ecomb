extends Node

# ============================================================================
# BATTLE MANAGER - Universal Rhythm Battle Mechanics
# ============================================================================
# Handles all combat mechanics shared across all rhythm battles:
# - Groove bar (health/failure system)
# - Combo tracking and multipliers
# - Hit quality tracking
# - Strength (XP) calculation
# - Battle results and rewards

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

# ============================================================================
# NOTE TYPE CONFIGURATION - Universal Note Definitions
# ============================================================================

# Note type configuration (scalable for future note types)
# To add a new note type:
#   1. Create scene file with appropriate size (e.g., HalfNote.tscn at 200x400)
#   2. Add entry here with scene path, travel_time, and spawn_offset
#   3. Add note type to level JSON files
#   4. All hit detection, spawn positioning, and timing automatically scale!
const NOTE_TYPE_CONFIG = {
	"whole": {
		"scene": preload("res://scenes/ui/battle/WholeNote.tscn"),  # 200x800
		"travel_time": 3.0,
		"spawn_offset": 17  # 3.0s at 152 BPM = 15.2, but empirically needs 17
	},
	"half": {
		"scene": preload("res://scenes/ui/battle/HalfNote.tscn"),  # 200x400
		"travel_time": 1.55,
		"spawn_offset": 8
	},
	"quarter": {
		"scene": preload("res://scenes/ui/battle/QuarterNote.tscn"),  # 200x200
		"travel_time": 1.55,
		"spawn_offset": 8  # 1.55s at 152 BPM = 7.85 ≈ 8 half-beats
	},
	"sixteenth": {
		"scene": preload("res://scenes/ui/battle/SixteenthNote.tscn"),  # 200x100
		"travel_time": 1.55,
		"spawn_offset": 8  # Same as quarter for now
	}
}

# ============================================================================
# HIT ZONE CONFIGURATION - Universal Hit Zone Settings
# ============================================================================

# Hit zone height (universal for now, may become dynamic for SixteenthNote songs)
const HITZONE_HEIGHT = 200.0

# Hit zone lane positions (3 lanes at y=650)
const HIT_ZONE_POSITIONS = {
	"1": Vector2(660.0, 650.0),
	"2": Vector2(860.0, 650.0),
	"3": Vector2(1060.0, 650.0)
}

# Spawn settings
const SPAWN_HEIGHT_ABOVE_TARGET = 1000.0

# Lane overlap prevention
const OVERLAP_PREVENTION_WINDOW = 6  # Half-beats window to prevent same-lane spawns
var recent_note_spawns = {}  # {beat_position: lane} - tracks recent spawns to avoid overlap

# ============================================================================
# DIFFICULTY SYSTEM - Hit Detection Thresholds
# ============================================================================

# Hit detection difficulty presets (percentages of HitZone height exposed)
# Used by battle scenes to determine Perfect/Good/Okay thresholds
# Themed around gym/fitness culture - respecting the grind!
const DIFFICULTY_PRESETS = {
	"wimpy": {
		"perfect": 0.25,   # 25% - for those who skip leg day (50px for 200px HitZone)
		"good": 0.50,      # 50% - warming up (100px for 200px)
		"okay": 0.90       # 90% - light stretch (180px for 200px)
	},
	"casual": {
		"perfect": 0.20,   # 20% - warming up (40px for 200px HitZone)
		"good": 0.40,      # 40% - getting started (80px for 200px)
		"okay": 0.85       # 85% - easy gains (170px for 200px)
	},
	"gymbro": {
		"perfect": 0.125,  # 12.5% - respect the grind (25px for 200px HitZone)
		"good": 0.25,      # 25% - balanced workout (50px for 200px)
		"okay": 0.75       # 75% - solid form (150px for 200px)
	},
	"meathead": {
		"perfect": 0.075,  # 7.5% - no pain no gain (15px for 200px HitZone)
		"good": 0.15,      # 15% - strict form (30px for 200px)
		"okay": 0.50       # 50% - heavy lifting (100px for 200px)
	},
	"gigachad": {
		"perfect": 0.05,   # 5% - LIGHT WEIGHT BABY! (10px for 200px HitZone)
		"good": 0.10,      # 10% - absolute beast mode (20px for 200px)
		"okay": 0.30       # 30% - ain't nothin' but a peanut (60px for 200px)
	}
}

# Current difficulty setting (persists across battles)
var current_difficulty: String = "gymbro"

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

func get_hit_quality_for_note(_distance: float, note: Node, hit_zone_y: float) -> String:
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

func create_fade_out_tween(note: Node, bpm: float) -> Tween:
	"""
	Create a universal fade out tween for hit notes.

	Notes fade based on their beat duration:
	- Whole notes: 4 beats
	- Half notes: 2 beats
	- Quarter notes: 1 beat
	- Sixteenth notes: 0.5 beats

	Notes continue falling by half their height during the fade.

	Args:
		note: The note node to fade
		bpm: Current song BPM for timing calculation

	Returns:
		Tween configured for fade animation
	"""
	if not is_instance_valid(note):
		return null

	# Stop the note from moving
	if note.has_method("stop_movement"):
		note.stop_movement()

	# Get note type from metadata to determine fade duration
	var note_type = note.get_meta("note_type", "quarter")

	# Map note type to beats
	var beats_to_fade = 1.0  # Default: quarter note = 1 beat
	match note_type:
		"whole":
			beats_to_fade = 4.0
		"half":
			beats_to_fade = 2.0
		"quarter":
			beats_to_fade = 1.0
		"sixteenth":
			beats_to_fade = 0.5

	# Calculate fade duration in seconds based on BPM
	var seconds_per_beat = 60.0 / bpm if bpm > 0 else 0.395  # Default 152 BPM
	var fade_duration = beats_to_fade * seconds_per_beat

	# Get note height to calculate fall distance (half of note height)
	var note_height = 200.0
	if note.has_node("NoteTemplate"):
		note_height = note.get_node("NoteTemplate").size.y
	var fall_distance = note_height / 2.0

	var current_y = note.position.y

	# Create fade out tween
	var fade_tween = note.create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(note, "modulate:a", 0.0, fade_duration)
	fade_tween.tween_property(note, "position:y", current_y + fall_distance, fade_duration)
	fade_tween.chain().tween_callback(func():
		if is_instance_valid(note):
			note.queue_free()
	)

	return fade_tween

# ============================================================================
# UNIVERSAL UI SETUP
# ============================================================================

func setup_battle_character_displays(player_sprite: AnimatedSprite2D, opponent_sprite: AnimatedSprite2D) -> Dictionary:
	"""
	Universal setup for Combo and XP displays attached to character sprites.

	This ensures ALL battles have consistent positioning and behavior for:
	- Combo display (attached to Player sprite, 50px above)
	- XP display (attached to Opponent sprite, 50px above)

	Both displays use dynamic positioning that scales with sprite size/scale.

	Args:
		player_sprite: The player's AnimatedSprite2D node
		opponent_sprite: The opponent's AnimatedSprite2D node

	Returns:
		Dictionary with keys:
			- combo_display: Label - Combo counter attached to player
			- xp_display: Label - XP popup attached to opponent
	"""
	var displays = {}

	# Combo Display - attached to Player sprite
	if player_sprite:
		var combo_display_scene = preload("res://scenes/ui/battle/ComboDisplay.tscn")
		var combo_display = combo_display_scene.instantiate()

		# Attach as child so it follows player (including jumps)
		player_sprite.add_child(combo_display)

		# Position dynamically based on sprite size (always 50px above sprite)
		combo_display.position = calculate_label_position_above_sprite(player_sprite, 50.0, 50.0)

		# Reset anchors for child-based positioning
		combo_display.anchor_left = 0.0
		combo_display.anchor_top = 0.0
		combo_display.anchor_right = 0.0
		combo_display.anchor_bottom = 0.0
		combo_display.offset_left = -200.0  # Half of 400px width to center
		combo_display.offset_top = -25.0   # Half of 50px height
		combo_display.offset_right = 200.0
		combo_display.offset_bottom = 25.0

		displays["combo_display"] = combo_display

	# XP Gain Display - attached to Opponent sprite
	if opponent_sprite:
		var xp_display_scene = preload("res://scenes/ui/battle/XPGainDisplay.tscn")
		var xp_display = xp_display_scene.instantiate()

		# Attach as child so it follows opponent (including jumps)
		opponent_sprite.add_child(xp_display)

		# Position dynamically based on sprite size (always 50px above sprite)
		xp_display.position = calculate_label_position_above_sprite(opponent_sprite, 50.0, 50.0)

		# Reset anchors for child-based positioning
		xp_display.anchor_left = 0.0
		xp_display.anchor_top = 0.0
		xp_display.anchor_right = 0.0
		xp_display.anchor_bottom = 0.0
		xp_display.offset_left = -100.0  # Half of 200px width to center
		xp_display.offset_top = -20.0   # Half of 40px height
		xp_display.offset_right = 100.0
		xp_display.offset_bottom = 20.0

		displays["xp_display"] = xp_display

	return displays

func calculate_label_position_above_sprite(sprite: AnimatedSprite2D, offset_above: float, label_height: float) -> Vector2:
	"""
	Calculate dynamic label position above an AnimatedSprite2D.

	This ensures labels always appear at the correct distance above sprites,
	regardless of sprite size or scale changes.

	Args:
		sprite: The AnimatedSprite2D to position above
		offset_above: How many pixels above the sprite top edge (e.g., 50.0)
		label_height: Height of the label in pixels (e.g., 50.0 for combo display)

	Returns:
		Vector2 position for the label relative to sprite center
	"""
	if not sprite or not sprite.sprite_frames:
		return Vector2(0, -200)  # Fallback

	# Get current frame texture to determine sprite size
	var current_animation = sprite.animation
	var current_frame = sprite.frame
	var texture = sprite.sprite_frames.get_frame_texture(current_animation, current_frame)

	if not texture:
		return Vector2(0, -200)  # Fallback

	# Calculate actual rendered height: texture height * sprite scale
	var texture_height = texture.get_height()
	var scaled_height = texture_height * sprite.scale.y

	# Sprite center is at (0, 0), so top edge is at -half_height
	var top_edge = -scaled_height / 2.0

	# Position label: top edge - offset above - half label height
	var label_y = top_edge - offset_above - (label_height / 2.0)

	return Vector2(0, label_y)

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
	- Rainbow: PERFECT hits
	- Cyan/Magenta/Yellow: Track-colored hits
	- Black/Gray: MISS

	Args:
		note: The note node (unused, for future extensions)
		color_type: "rainbow", "cyan", "magenta", "yellow", "white", or "black"
		intensity: Explosion strength (1-5), affects particle count
		explosion_pos: Center position for explosion
		effects_layer: Node2D to add particles to
		scene_root: Root node for create_tween()
	"""
	# Clamp explosion center to screen bounds so it's visible even if note is off-screen
	var viewport_size = get_viewport().get_visible_rect().size
	var note_center = Vector2(
		clamp(explosion_pos.x, 100, viewport_size.x - 100),
		clamp(explosion_pos.y, 100, viewport_size.y - 100)
	)
	var particle_count = intensity * 20

	for i in range(particle_count):
		var particle = ColorRect.new()
		var particle_size = randi_range(8, 25)
		particle.size = Vector2(particle_size, particle_size)
		particle.pivot_offset = particle.size / 2

		match color_type:
			"rainbow":
				var rainbow_colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.CYAN, Color.BLUE, Color.PURPLE, Color.MAGENTA, Color.PINK]
				particle.color = rainbow_colors[i % rainbow_colors.size()]
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
		effects_layer.add_child(particle)

		# Capture particle in local variable for lambda
		var p = particle
		var tween = scene_root.create_tween()
		tween.set_parallel(true)

		# Original explosion behavior: larger radius, longer duration
		var explosion_radius = 600 if color_type == "rainbow" else 450
		var random_direction = Vector2(randf_range(-explosion_radius, explosion_radius), randf_range(-explosion_radius, explosion_radius))
		var duration = randf_range(0.8, 1.5)

		tween.tween_property(p, "position", p.position + random_direction, duration)
		tween.tween_property(p, "rotation", p.rotation + randf_range(-TAU * 2, TAU * 2), duration)
		tween.tween_property(p, "modulate:a", 0.0, duration)
		tween.tween_property(p, "scale", Vector2(3.0, 3.0), duration * 0.2)
		tween.tween_property(p, "scale", Vector2(0.0, 0.0), duration * 0.8).set_delay(duration * 0.2)
		tween.tween_callback(func():
			if is_instance_valid(p):
				p.queue_free()
		).set_delay(duration)

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
	# Capture label in local variable for lambda
	var lbl = label
	var move_tween = scene_root.create_tween()
	move_tween.set_parallel(true)
	move_tween.tween_property(lbl, "position:y", lbl.position.y - 80, 0.8)
	move_tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
	move_tween.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free()
	).set_delay(1.0)

# ============================================================================
# CHARACTER ANIMATIONS
# ============================================================================

# Animation pools - Add new animations here to randomly select from
const PLAYER_PERFECT_ANIMATIONS = ["pecs"]  # Add more: ["pecs", "flex", "dance"]
const PLAYER_GOOD_ANIMATIONS = []           # Add if desired: ["nod", "thumbsup"]
const PLAYER_OKAY_ANIMATIONS = []           # Add if desired: ["shrug"]
const OPPONENT_MISS_ANIMATIONS = []         # Add more: ["laugh", "taunt", "celebrate"]

func animate_player_hit(player_sprite: AnimatedSprite2D, player_original_pos: Vector2, quality: String, scene_root: Node):
	"""Animate player character on successful hit.

	Universal player animations with random selection:
	- PERFECT: Randomly picks from PLAYER_PERFECT_ANIMATIONS + jump 60px
	- GOOD: Randomly picks from PLAYER_GOOD_ANIMATIONS (optional)
	- OKAY: Randomly picks from PLAYER_OKAY_ANIMATIONS (optional)

	Args:
		player_sprite: Player's AnimatedSprite2D
		player_original_pos: Player's original Y position for jump
		quality: Hit quality ("PERFECT", "GOOD", "OKAY")
		scene_root: Root node for create_tween()
	"""
	var animation_pool = []

	match quality:
		"PERFECT":
			animation_pool = PLAYER_PERFECT_ANIMATIONS
		"GOOD":
			animation_pool = PLAYER_GOOD_ANIMATIONS
		"OKAY":
			animation_pool = PLAYER_OKAY_ANIMATIONS

	# Play random animation from pool if available
	if animation_pool.size() > 0 and player_sprite and player_sprite.sprite_frames:
		# Randomly select an animation from the pool
		var random_animation = animation_pool[randi() % animation_pool.size()]

		# Only play if the sprite actually has this animation
		if player_sprite.sprite_frames.has_animation(random_animation):
			# Disconnect any existing connection
			if player_sprite.animation_finished.is_connected(_on_player_pecs_finished):
				player_sprite.animation_finished.disconnect(_on_player_pecs_finished)

			player_sprite.play(random_animation)

			# Connect one-shot to return to idle
			player_sprite.animation_finished.connect(
				func():
					if is_instance_valid(player_sprite) and player_sprite.sprite_frames:
						if player_sprite.sprite_frames.has_animation("idle"):
							player_sprite.play("idle")
				, CONNECT_ONE_SHOT
			)

	# Jump animation (only on PERFECT)
	if quality == "PERFECT" and player_sprite:
		var tween = scene_root.create_tween()
		tween.set_parallel(true)
		tween.tween_property(player_sprite, "position:y", player_original_pos.y - 60, 0.25)
		tween.tween_property(player_sprite, "position:y", player_original_pos.y, 0.25).set_delay(0.25)

func _on_player_pecs_finished():
	"""Callback stub for animation_finished signal."""
	pass

func animate_opponent_miss(opponent_sprite: AnimatedSprite2D, opponent_original_pos: Vector2, scene_root: Node):
	"""Animate opponent character on player MISS.

	Universal opponent animation with random selection:
	- Randomly picks from OPPONENT_MISS_ANIMATIONS (if pool not empty)
	- Falls back to jump animation if pool is empty
	- Returns to idle after animation finishes

	Args:
		opponent_sprite: Opponent's AnimatedSprite2D
		opponent_original_pos: Opponent's original Y position for jump
		scene_root: Root node for create_tween()
	"""
	if not opponent_sprite:
		return

	# Try to play random animation from pool
	if OPPONENT_MISS_ANIMATIONS.size() > 0 and opponent_sprite.sprite_frames:
		# Randomly select an animation from the pool
		var random_animation = OPPONENT_MISS_ANIMATIONS[randi() % OPPONENT_MISS_ANIMATIONS.size()]

		# Only play if the sprite actually has this animation
		if opponent_sprite.sprite_frames.has_animation(random_animation):
			opponent_sprite.play(random_animation)

			# Connect one-shot to return to idle
			opponent_sprite.animation_finished.connect(
				func():
					if is_instance_valid(opponent_sprite) and opponent_sprite.sprite_frames:
						if opponent_sprite.sprite_frames.has_animation("idle"):
							opponent_sprite.play("idle")
				, CONNECT_ONE_SHOT
			)

			# Jump during animation
			var tween = scene_root.create_tween()
			tween.set_parallel(true)
			tween.tween_property(opponent_sprite, "position:y", opponent_original_pos.y - 60, 0.25)
			tween.tween_property(opponent_sprite, "position:y", opponent_original_pos.y, 0.25).set_delay(0.25)
			return

	# Fallback: Just jump animation (original behavior)
	opponent_sprite.pause()
	var os = opponent_sprite  # Capture for lambda
	var tween = scene_root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(os, "position:y", opponent_original_pos.y - 60, 0.25)
	tween.tween_property(os, "position:y", opponent_original_pos.y, 0.25).set_delay(0.25)
	tween.tween_callback(func():
		if is_instance_valid(os):
			os.play()
	).set_delay(0.5)
