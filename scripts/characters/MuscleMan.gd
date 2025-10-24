extends AnimatedSprite2D

var is_flexing = false

func _ready():
	flip_h = true
	play("walk")
	
	# Start position (off-screen to the right)
	position.x = 2100
	position.y = 786
	
	# Move him into frame
	var tween = create_tween()
	tween.tween_property(self, "position:x", 925, 5.0)
	tween.tween_callback(func(): play("idle"))

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if modal is open
		var title_scene = get_tree().get_first_node_in_group("title_scene")
		if title_scene and title_scene.has_method("is_modal_open") and title_scene.is_modal_open():
			return
		
		# Only allow clicking during idle animation
		if animation != "idle":
			return
		
		if is_flexing:
			return
			
		# Check if click is on the sprite
		var mouse_pos = get_local_mouse_position()
		var texture_size = sprite_frames.get_frame_texture(animation, frame).get_size()
		var sprite_rect = Rect2(-texture_size / 2, texture_size)
		
		if sprite_rect.has_point(mouse_pos):
			is_flexing = true
			
			var original_scale = scale
			var tween = create_tween()
			tween.tween_property(self, "scale", original_scale * 1.05, 0.2)
			
			play("pecs")
			# From UI/MuscleMan to Audio/MuscleManSound:
			$"../../MuscleManSound".play()
						
			await animation_finished
			
			var tween2 = create_tween()
			tween2.tween_property(self, "scale", original_scale, 0.2)
			
			play("idle")
			is_flexing = false
			
			get_viewport().set_input_as_handled()
