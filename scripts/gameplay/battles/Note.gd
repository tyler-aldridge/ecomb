extends Area2D

var speed: float
var target_y: float
var track_key: String
var spawn_height: float = 1000.0
var travel_time: float = 2.0

func setup(key: String, start_pos: Vector2, target_position: float):
	track_key = key
	position = start_pos
	target_y = target_position
	speed = spawn_height / travel_time

	var color_rect = $NoteTemplate
	if color_rect.size.y <= 200:
		color_rect.size = Vector2(200, 200)

	match key:
		"1":
			color_rect.color = Color.CYAN
		"2":
			color_rect.color = Color.MAGENTA
		"3":
			color_rect.color = Color.YELLOW

func set_travel_time(time: float):
	travel_time = time
	speed = spawn_height / travel_time

func _physics_process(delta):
	if speed > 0:  # Only move if speed is positive
		position.y += speed * delta
	if position.y > target_y + 400:
		queue_free()

func stop_movement():
	speed = 0
	set_physics_process(false)
