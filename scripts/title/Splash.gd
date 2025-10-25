extends Node
@onready var anim = $SplashAnimation
@onready var splash_text = $SplashText
var original_pos: Vector2

func _ready():
	# Wait a frame for the label to be properly sized
	await get_tree().process_frame
	position_splash_text()
	
	# Start both animations
	anim.play("splash")
	animate_splash_text()
	
	anim.animation_finished.connect(_on_animation_finished)

func position_splash_text():
	if splash_text:
		var viewport_size = get_viewport().get_visible_rect().size
		
		# Set font size to 50px
		splash_text.add_theme_font_size_override("font_size", 50)
		
		# Reset anchors to default (0,0,0,0)
		splash_text.anchor_left = 0.0
		splash_text.anchor_right = 0.0
		splash_text.anchor_top = 0.0
		splash_text.anchor_bottom = 0.0
		
		# Set pivot to center of the label for proper scaling
		splash_text.pivot_offset = splash_text.size * 0.5
		
		# Calculate bottom center position
		var label_width = splash_text.size.x
		var label_height = splash_text.size.y
		
		var center_x = (viewport_size.x - label_width) * 0.5
		var bottom_y = viewport_size.y - label_height - 50.0  # 25px from bottom
		
		splash_text.position = Vector2(center_x, bottom_y)
		original_pos = splash_text.position  # Store original position for shake
		
		# Start invisible/scaled to zero
		splash_text.scale = Vector2.ZERO
		splash_text.modulate.a = 0.0

func animate_splash_text():
	# Wait 0.35 seconds before starting scale-in
	await get_tree().create_timer(0.35).timeout
	
	# Scale in animation
	var scale_tween = create_tween()
	scale_tween.set_parallel(true)
	scale_tween.tween_property(splash_text, "scale", Vector2.ONE, 0.3)
	scale_tween.tween_property(splash_text, "modulate:a", 1.0, 0.3)
	
	# Wait until 0.75 seconds total (0.4 more seconds)
	await get_tree().create_timer(0.4).timeout
	
	# More dramatic shake with both X and Y movement
	var shake_tween = create_tween()
	shake_tween.set_loops(1)
	shake_tween.tween_method(shake_position, 0.0, 1.0, 0.5)

func shake_position(_progress: float):
	var shake_intensity = 8.0
	var random_offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)
	splash_text.position = original_pos + random_offset

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "splash":
		Router.goto_scene("res://scenes/title/MainTitle.tscn")
