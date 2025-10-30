extends Node

# Persistent fade overlay that stays across scene transitions
var fade_overlay: ColorRect = null

func _ready():
	# Create persistent fade overlay that covers scene transitions
	var viewport = get_viewport()
	if viewport:
		fade_overlay = ColorRect.new()
		fade_overlay.color = Color.BLACK
		fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade_overlay.z_index = 100  # High z-index within the layer

		# Create CanvasLayer to ensure it's always on top
		var canvas_layer = CanvasLayer.new()
		canvas_layer.layer = 1000  # Very high layer - this is what matters most
		add_child(canvas_layer)
		canvas_layer.add_child(fade_overlay)

		# Start invisible
		fade_overlay.modulate.a = 0.0

		# Size to viewport
		_resize_overlay()
		get_tree().root.size_changed.connect(_resize_overlay)

func _resize_overlay():
	if fade_overlay:
		fade_overlay.size = get_viewport().get_visible_rect().size
		fade_overlay.position = Vector2.ZERO

func goto_scene(path: String) -> void:
	get_tree().change_scene_to_file(path)

func goto_scene_with_fade(path: String, fade_duration: float = 1.5) -> void:
	"""Fade out, change scene, fade in with persistent overlay to prevent flash."""
	if not fade_overlay:
		# Fallback if overlay not ready
		goto_scene(path)
		return

	# Fade to black
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, fade_duration).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		# Change scene while black overlay is up
		get_tree().change_scene_to_file(path)
		# Wait a frame for new scene to load
		await get_tree().process_frame
		# Fade from black
		var fade_in_tween = create_tween()
		fade_in_tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT)
	)
