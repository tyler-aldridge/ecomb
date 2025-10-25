extends Node

var dialog_box_scene := preload("res://scenes/ui/universal/DialogBox.tscn")
var current_dialog: Control = null

func show_dialog(text: String, _character: String, auto_close_time: float, _dialog_id: String = "") -> void:
	# Add a small delay to prevent immediate replacement
	await get_tree().create_timer(0.1).timeout
	
	if current_dialog:
		current_dialog.queue_free()
	
	current_dialog = dialog_box_scene.instantiate()
	
	# Set high z-index to appear above everything else
	current_dialog.z_index = 1000
	
	# Add to scene first
	if get_tree().current_scene:
		get_tree().current_scene.add_child(current_dialog)
	else:
		get_tree().root.add_child(current_dialog)
	
	# Find the text node
	var text_node: RichTextLabel = null
	for child in current_dialog.get_children():
		if child is RichTextLabel:
			text_node = child
			break
	
	if text_node:
		# Set the text
		_set_text(text_node, text)
		
		# Calculate desired width based on text length
		var char_count = text.length()
		var estimated_width = char_count * 15
		var min_width = 400
		var max_width = get_viewport().get_visible_rect().size.x * 0.8
		var desired_width = clamp(estimated_width + 60, min_width, max_width)
		
		# Set the size of the main dialog container - let the children follow
		current_dialog.size.x = desired_width
		
		# If the text is very long, allow wrapping and increase height
		if estimated_width > max_width - 60:
			text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			current_dialog.size.y = 120  # Taller for wrapped text
		else:
			text_node.autowrap_mode = TextServer.AUTOWRAP_OFF
			current_dialog.size.y = 80   # Standard height
	
	# Wait for the dialog to process its new size
	await get_tree().process_frame
	
	# Center the dialog at the top of the screen
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = (viewport_size.x - current_dialog.size.x) * 0.5
	var top_margin = 300.0
	
	current_dialog.position = Vector2(center_x, top_margin)
	
	# Reset anchors to ensure proper positioning
	current_dialog.anchor_left = 0.0
	current_dialog.anchor_right = 0.0
	current_dialog.anchor_top = 0.0
	current_dialog.anchor_bottom = 0.0
	
	# Now animate the text typing
	if text_node:
		_set_text(text_node, "")
		await _type_text(text_node, text)
	
	# Use the original timer system but with better timing
	if auto_close_time > 0.0:
		var timer := get_tree().create_timer(auto_close_time)
		var dialog_ref = current_dialog  # Store reference to avoid null issues
		timer.timeout.connect(func():
			if is_instance_valid(dialog_ref):
				var tw := create_tween()
				tw.tween_property(dialog_ref, "modulate:a", 0.0, 0.4)
				tw.tween_callback(func():
					if is_instance_valid(dialog_ref):
						dialog_ref.queue_free()
					if current_dialog == dialog_ref:
						current_dialog = null
				)
		)

func show_countdown(numbers: Array, per_number_seconds: float, font_size: int = 600) -> void:
	for i in range(numbers.size()):
		var delay := float(i) * per_number_seconds
		_spawn_number_later(str(numbers[i]), delay, font_size, Color.WHITE if str(numbers[i]) != "GO!" else Color.RED, 0.8)

func show_countdown_number(text: String, seconds: float, font_size: int, color: Color) -> void:
	_spawn_number_later(text, 0.0, font_size, color, seconds)

func _set_text(node: Node, value: String) -> void:
	if node is Label or node is RichTextLabel:
		node.text = value

func _type_text(node: Node, full_text: String) -> void:
	for i in range(full_text.length() + 1):
		if not is_instance_valid(node):
			return
		_set_text(node, full_text.substr(0, i))
		await get_tree().create_timer(0.02).timeout

func _spawn_number_later(text: String, delay: float, font_size: int, color: Color, linger: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(Callable(self, "_spawn_number_now").bind(text, font_size, color, linger))

func _spawn_number_now(text: String, font_size: int, color: Color, linger: float) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Center the countdown numbers - use large enough size for any text
	var viewport_size = get_viewport().get_visible_rect().size
	var label_width = font_size * 2  # Wide enough for any countdown text
	var label_height = font_size * 1.5  # Tall enough for the font
	label.size = Vector2(label_width, label_height)
	label.position = Vector2(viewport_size.x * 0.5 - label_width * 0.5, viewport_size.y * 0.5 - label_height * 0.5)
	
	var layer := CanvasLayer.new()
	layer.layer = 100
	if get_tree().current_scene:
		get_tree().current_scene.add_child(layer)
	else:
		get_tree().root.add_child(layer)
	layer.add_child(label)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 80.0, 0.8 + linger)
	tw.tween_property(label, "modulate:a", 0.0, 0.8 + linger)
	tw.tween_callback(layer.queue_free).set_delay(0.8 + linger)
