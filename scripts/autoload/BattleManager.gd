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
