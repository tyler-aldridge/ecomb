extends Area2D

## ============================================================================
## GRID-BASED NOTE POSITIONING
## ============================================================================
## Notes calculate their position DIRECTLY from audio time every frame.
## This eliminates timing drift, pause/unpause issues, and offset problems.
##
## Grid Coordinate System:
## - Column (lane): "1", "2", "3", "4", "5"
## - Row (beat_position): Integer beat position (0 = Bar 1 Beat 1)
##
## Position is a pure function of: beat_position - current_beat
## No accumulation, no drift, always accurate.

# Grid coordinates (set once, never changes)
var lane: String = "1"
var beat_position: int = 0  # When this note should be hit (grid row)
var note_type: String = "quarter"

# References
var conductor = null
var hitzone_y: float = 0.0

# Visual state
var is_active: bool = false

func setup_grid(p_lane: String, p_beat_position: int, p_note_type: String, p_conductor, p_hitzone_y: float):
	"""Initialize note with grid coordinates.

	Args:
		p_lane: Lane key ("1", "2", "3", "4", "5")
		p_beat_position: Beat position when note should be hit
		p_note_type: Type of note ("whole", "half", "quarter")
		p_conductor: Reference to Conductor for timing
		p_hitzone_y: Y position of hitzone
	"""
	lane = p_lane
	beat_position = p_beat_position
	note_type = p_note_type
	conductor = p_conductor
	hitzone_y = p_hitzone_y
	is_active = true

	# Set X position (column) - never changes
	position.x = BattleManager.HIT_ZONE_POSITIONS[lane].x

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

func deactivate():
	"""Return note to pool (reset state)."""
	is_active = false
	visible = false
	lane = ""
	beat_position = 0
	conductor = null

func _physics_process(_delta):
	if not is_active or not conductor:
		return

	# Calculate position from grid coordinates (row)
	# Use float beats for SMOOTH visual motion (not choppy integer steps)
	var current_beat = conductor.song_position_in_beats_float
	var beats_until_hit = beat_position - current_beat

	# Convert beats to pixels (BPM affects visual speed)
	var pixels_per_beat = BattleManager.get_pixels_per_beat(conductor.bpm)
	var distance_from_hitzone = beats_until_hit * pixels_per_beat

	# Get note height dynamically
	var note_height = $NoteTemplate.size.y if has_node("NoteTemplate") else 200.0

	# Set Y position with CENTER alignment
	# At beat_position (beats_until_hit = 0): center of note aligns with center of hitzone
	# Formula: position.y = hitzone_center_y - note_center_offset - distance
	var hitzone_center_y = hitzone_y + BattleManager.HITZONE_HEIGHT / 2.0
	var note_center_offset = note_height / 2.0
	position.y = hitzone_center_y - note_center_offset - distance_from_hitzone

	# Visibility and despawn based on grid position
	if beats_until_hit > BattleManager.SPAWN_AHEAD_BEATS:
		visible = false  # Too far in future
	elif beats_until_hit < -BattleManager.DESPAWN_BEHIND_BEATS:
		# Passed hitzone, ready for removal (battle scene will return to pool)
		visible = false
	else:
		visible = true

func is_past_despawn_threshold() -> bool:
	"""Check if note is past the despawn threshold.

	Returns:
		true if note should be returned to pool
	"""
	if not conductor:
		return true
	var current_beat = conductor.song_position_in_beats
	var beats_until_hit = beat_position - current_beat
	return beats_until_hit < -BattleManager.DESPAWN_BEHIND_BEATS

# Legacy compatibility (battle scenes may still call these)
func setup(_key: String, _start_pos: Vector2, _target_position: float):
	pass  # Deprecated - use setup_grid instead

func set_travel_time_and_distance(_time: float, _distance: float):
	pass  # Deprecated - grid system calculates this automatically

func stop_movement():
	pass  # Deprecated - grid system doesn't use movement

# Expose track_key for compatibility with hit detection
var track_key: String:
	get:
		return lane
