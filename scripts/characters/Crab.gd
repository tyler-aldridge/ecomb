extends AnimatedSprite2D

var is_dead = false

func _ready():
	# Set starting position (off-screen)
	position = Vector2(-81, 767)
	
	# Start playing the walking animation
	play("walking")
	
	# Wait 8 seconds before moving
	await get_tree().create_timer(8.0).timeout
	
	# Create tween to move the crab
	var tween = create_tween()
	tween.tween_property(self, "position", Vector2(128, 765), 3.0)  # Move over 3 seconds
	tween.tween_callback(func():
		if is_instance_valid(self):
			play("idle")  # Switch to idle when he arrives
	)

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if modal is open - don't process input if so
		var title_scene = get_tree().get_first_node_in_group("title_scene")
		if title_scene and title_scene.has_method("is_modal_open") and title_scene.is_modal_open():
			return
		
		# Only allow clicking during idle animation
		if animation != "idle":
			return
			
		if is_dead:
			return
			
		# Check if click is on the crab
		var mouse_pos = get_local_mouse_position()
		var texture_size = sprite_frames.get_frame_texture(animation, frame).get_size()
		var sprite_rect = Rect2(-texture_size / 2, texture_size)
		
		if sprite_rect.has_point(mouse_pos):
			die()
			get_viewport().set_input_as_handled()

func die():
	is_dead = true
	stop()  # Stop the animation
	$"../../CrabSound".play()  # Play the death sound
	
	var start_x = position.x
	var start_y = position.y
	
	# Animate with manual control
	animate_death(start_x, start_y)

func animate_death(start_x: float, start_y: float):
	# Go up 75px
	var tween1 = create_tween()
	tween1.set_parallel(true)
	tween1.tween_property(self, "position:x", start_x, 0.2)
	tween1.tween_property(self, "position:y", start_y - 100, 0.2)
	tween1.tween_property(self, "rotation_degrees", 90, 0.2)
	
	await tween1.finished
	
	# Fall down to 45px above start
	var tween2 = create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(self, "position:x", start_x, 0.3)
	tween2.tween_property(self, "position:y", start_y + 5, 0.3)
	tween2.tween_property(self, "rotation_degrees", 180, 0.3)
