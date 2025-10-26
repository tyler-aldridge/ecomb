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
