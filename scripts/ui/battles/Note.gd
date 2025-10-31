extends Area2D

## ============================================================================
## POSITION INTERPOLATION NOTE MOVEMENT - INDUSTRY STANDARD
## ============================================================================
## Notes calculate position from beat progress each frame (not velocity).
## This approach is self-correcting and frame-rate independent.
##
## System:
## - Notes store their target beat (when they should be hit)
## - Position is calculated: lerp(spawn_y, target_y, progress)
## - Progress = 1.0 - (beats_until_hit / beats_shown_in_advance)
## - Frame drops are immediately corrected next frame
## - No accumulation errors, no drift
## ============================================================================

# Configuration (set once on spawn)
var note_beat: float = 0.0  # When this note should be hit (in ticks)
var lane: String = "1"
var note_type: String = "quarter"

# Visual configuration
var spawn_y: float = -900.0
var target_y: float = 750.0  # Hitzone center
var beats_shown_in_advance: float = 6.0  # How many ticks ahead to spawn

# References
var conductor = null

# Visual state
var is_active: bool = false

# Screen bounds for despawn
var despawn_progress: float = 1.2  # Despawn when 20% past target (configurable)

func setup_interpolation(p_lane: String, p_note_beat: float, p_note_type: String, p_conductor, p_spawn_y: float, p_target_y: float, p_beats_advance: float):
	"""Initialize note with position interpolation movement.

	Args:
		p_lane: Lane key ("1", "2", "3", "4", "5")
		p_note_beat: Beat position when note should be hit (in ticks)
		p_note_type: Type of note ("whole", "half", "quarter")
		p_conductor: Reference to Conductor for timing
		p_spawn_y: Y position to spawn at (off-screen above hitzone)
		p_target_y: Y position of hitzone center
		p_beats_advance: How many beats ahead to show notes
	"""
	lane = p_lane
	note_beat = p_note_beat
	note_type = p_note_type
	conductor = p_conductor
	spawn_y = p_spawn_y
	target_y = p_target_y
	beats_shown_in_advance = p_beats_advance
	is_active = true

	# Set X position (column) - never changes
	position.x = BattleManager.HIT_ZONE_POSITIONS[lane].x

	# Initial Y position will be calculated in _process
	position.y = spawn_y

	# Set color based on lane
	var color_rect = $NoteTemplate
	if color_rect.size.y <= 200:
		color_rect.size = Vector2(200, 200)

	match lane:
		"1":
			color_rect.color = Color.CYAN
		"2":
			color_rect.color = Color.MAGENTA
		"3":
			color_rect.color = Color.YELLOW
		"4":
			color_rect.color = Color.GREEN
		"5":
			color_rect.color = Color.ORANGE

	visible = true

func deactivate():
	"""Deactivate note (reset state)."""
	is_active = false
	visible = false
	lane = ""
	note_beat = 0.0
	conductor = null

func _process(_delta):
	if not is_active or not conductor:
		return

	# CRITICAL: Calculate position from beat progress, not velocity
	var current_beat = conductor.song_pos_in_beats

	# How far until this note should be hit?
	var beats_until_hit = note_beat - current_beat

	# Calculate progress (0.0 at spawn, 1.0 at target)
	var progress = 1.0 - (beats_until_hit / beats_shown_in_advance)

	# Interpolate position based on progress
	position.y = lerp(spawn_y, target_y, progress)

	# Despawn when past screen (20% beyond target)
	if progress > despawn_progress:
		visible = false

func is_past_despawn_threshold() -> bool:
	"""Check if note is past the despawn threshold.

	Returns:
		true if note should be removed
	"""
	if not conductor:
		return true

	var current_beat = conductor.song_pos_in_beats
	var beats_until_hit = note_beat - current_beat
	var progress = 1.0 - (beats_until_hit / beats_shown_in_advance)

	return progress > despawn_progress

func stop_movement():
	"""Stop note movement (for hit/miss effects)."""
	is_active = false

# Expose track_key for compatibility with hit detection
var track_key: String:
	get:
		return lane

# Legacy compatibility wrapper for velocity system
func setup_velocity(p_lane: String, p_beat_position: int, p_note_type: String, p_conductor, _spawn_y: float, _target_y: float, fall_time: float):
	"""Legacy velocity setup - converts to interpolation system.

	DEPRECATED: Use setup_interpolation instead.
	This exists for backward compatibility during migration.
	"""
	# Calculate beats_advance from fall_time
	var beats_advance = (fall_time / p_conductor.sec_per_beat) * p_conductor.subdivision

	# Use interpolation setup
	setup_interpolation(p_lane, float(p_beat_position), p_note_type, p_conductor, _spawn_y, _target_y, beats_advance)
