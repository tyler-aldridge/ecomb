extends Area2D

## ============================================================================
## VELOCITY-BASED NOTE MOVEMENT
## ============================================================================
## Notes move at CONSTANT VELOCITY (position += speed * delta).
## This is the standard rhythm game approach - notes spawn at a fixed distance
## and fall at constant speed. Hit detection uses TIME windows, not position.
##
## System:
## - Notes spawn at a fixed Y position above the hitzone
## - Notes move downward at constant speed (pixels/second)
## - Notes track their expected_time (when player should hit)
## - Hit detection compares current_time vs expected_time
## - No recalculation, no drift, always accurate

# Grid coordinates (set once, never changes)
var lane: String = "1"
var beat_position: int = 0  # Beat when this note should be hit
var note_type: String = "quarter"

# Movement properties
var speed: float = 0.0  # Pixels per second (constant velocity)
var expected_time: float = 0.0  # Song time when player should hit this note

# References
var conductor = null

# Visual state
var is_active: bool = false

# Screen bounds for despawn
const SCREEN_BOTTOM: float = 1200.0  # Notes despawn when they go off bottom

func setup_velocity(p_lane: String, p_beat_position: int, p_note_type: String, p_conductor, spawn_y: float, target_y: float, fall_time: float):
	"""Initialize note with velocity-based movement.

	Args:
		p_lane: Lane key ("1", "2", "3", "4", "5")
		p_beat_position: Beat position when note should be hit (for tracking only)
		p_note_type: Type of note ("whole", "half", "quarter")
		p_conductor: Reference to Conductor for timing
		spawn_y: Y position to spawn at (off-screen above hitzone)
		target_y: Y position of hitzone center
		fall_time: Time in seconds for note to reach hitzone
	"""
	lane = p_lane
	beat_position = p_beat_position
	note_type = p_note_type
	conductor = p_conductor
	is_active = true

	# Calculate constant velocity: speed = distance / time
	var distance = target_y - spawn_y
	speed = distance / fall_time

	# Calculate expected hit time (current song position + fall time)
	expected_time = conductor.song_position + fall_time

	# Set X position (column) - never changes
	position.x = BattleManager.HIT_ZONE_POSITIONS[lane].x

	# Set initial Y position (spawn off-screen)
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
	"""Return note to pool (reset state)."""
	is_active = false
	visible = false
	lane = ""
	beat_position = 0
	conductor = null
	speed = 0.0
	expected_time = 0.0

func _physics_process(delta):
	if not is_active:
		return

	# Constant velocity movement (THIS IS THE CORRECT APPROACH)
	position.y += speed * delta

	# Despawn when note goes off bottom of screen
	if position.y >= SCREEN_BOTTOM:
		visible = false

func is_past_despawn_threshold() -> bool:
	"""Check if note is past the despawn threshold.

	Returns:
		true if note should be returned to pool
	"""
	return position.y >= SCREEN_BOTTOM

func test_hit(current_time: float, tolerance: float = 0.08) -> bool:
	"""Time-based hit detection (rhythm game standard).

	Args:
		current_time: Current song position in seconds
		tolerance: Time window for acceptable hit (default 0.08s = 80ms = OKAY window)

	Returns:
		true if hit is within time window
	"""
	return abs(expected_time - current_time) <= tolerance

func test_miss(current_time: float, tolerance: float = 0.08) -> bool:
	"""Check if note has been missed (time-based).

	Args:
		current_time: Current song position in seconds
		tolerance: Time window past expected_time to consider missed

	Returns:
		true if note is past the miss window
	"""
	return current_time > expected_time + tolerance

# Legacy compatibility (battle scenes may still call these)
func setup(_key: String, _start_pos: Vector2, _target_position: float):
	pass  # Deprecated - use setup_velocity instead

func setup_grid(_lane: String, _beat_position: int, _note_type: String, _conductor, _hitzone_y: float):
	pass  # Deprecated - use setup_velocity instead

func set_travel_time_and_distance(_time: float, _distance: float):
	pass  # Deprecated - velocity system calculates this automatically

func stop_movement():
	"""Stop note movement (for hit/miss effects)."""
	is_active = false

# Expose track_key for compatibility with hit detection
var track_key: String:
	get:
		return lane
