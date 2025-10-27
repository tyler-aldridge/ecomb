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

	# Start off-screen to prevent flash at default position
	current_dialog.position = Vector2(-5000, -5000)

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

		# Calculate desired width based on text length and character position
		# Side dialogs (opponent/player) should be narrower to avoid blocking gameplay
		var char_count = text.length()
		var estimated_width = char_count * 15
		var min_width = 300.0
		var max_width = 600.0 if (_character == "opponent" or _character == "player") else get_viewport().get_visible_rect().size.x * 0.8
		var desired_width = clamp(estimated_width + 60, min_width, max_width)

		# Set the size of the main dialog container - let the children follow
		current_dialog.size.x = desired_width

		# Enable text wrapping for better readability
		text_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Calculate height dynamically based on text length
		# Estimate lines needed: char_count / chars_per_line
		var chars_per_line = (desired_width - 100) / 12  # Rough estimate
		var estimated_lines = ceil(float(char_count) / chars_per_line)
		var line_height = 25  # Approximate height per line
		var base_height = 60  # Padding
		var calculated_height = base_height + (estimated_lines * line_height)
		current_dialog.size.y = clamp(calculated_height, 80, 200)
	
	# Wait for the dialog to process its new size
	await get_tree().process_frame

	# Position based on character speaking
	var viewport_size = get_viewport().get_visible_rect().size
	var dialog_pos: Vector2

	if _character == "opponent":
		# Position centered over opponent sprite, closer to it (moved down from Y=300)
		var center_x = 1620.0 - current_dialog.size.x / 2.0
		# Position lower, closer to sprite (sprite around Y=310)
		var top_y = 450.0

		# Clamp to screen bounds
		center_x = clamp(center_x, 50.0, viewport_size.x - current_dialog.size.x - 50.0)

		# Avoid HitZone overlap (HitZones are Y=650-850)
		# Make sure bottom of dialog doesn't go into HitZones
		var dialog_bottom = top_y + current_dialog.size.y
		if dialog_bottom > 600.0:  # 50px buffer above HitZones
			top_y = 600.0 - current_dialog.size.y

		dialog_pos = Vector2(center_x, top_y)
	elif _character == "player":
		# Position centered over player sprite (typically at world X=~202)
		var center_x = 300.0 - current_dialog.size.x / 2.0
		var top_y = 300.0

		# Clamp to screen bounds
		center_x = clamp(center_x, 50.0, viewport_size.x - current_dialog.size.x - 50.0)

		# Avoid HitZone overlap
		var dialog_bottom = top_y + current_dialog.size.y
		if dialog_bottom > 600.0:
			top_y = 600.0 - current_dialog.size.y

		dialog_pos = Vector2(center_x, top_y)
	else:
		# Default: center at top
		var center_x = (viewport_size.x - current_dialog.size.x) * 0.5
		var top_margin = 300.0
		dialog_pos = Vector2(center_x, top_margin)

	current_dialog.position = dialog_pos
	
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
		# Don't use .bind() with timeout signal - it doesn't accept parameters!
		# Instead, capture the dialog reference in a lambda (safe here - not in a loop)
		var dialog_ref = current_dialog
		timer.timeout.connect(func(): _close_dialog_after_timer(dialog_ref))

func show_countdown(numbers: Array, per_number_seconds: float, font_size: int = 600) -> void:
	for i in range(numbers.size()):
		var delay := float(i) * per_number_seconds
		var number_text = str(numbers[i])
		var is_go = number_text == "GO!"
		# 3,2,1 have half the linger time (0.1), GO! has normal (0.2)
		var linger_time = 0.2 if is_go else 0.1
		_spawn_number_later(number_text, delay, font_size, Color.WHITE if not is_go else Color.RED, linger_time, is_go)

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

func _close_dialog_after_timer(dialog_ref: Control):
	"""Callback to close dialog after timer - avoids nested lambdas."""
	if is_instance_valid(dialog_ref):
		# Capture dialog_ref to avoid it being freed before callback
		var d = dialog_ref
		var tw := create_tween()
		tw.tween_property(d, "modulate:a", 0.0, 0.4)
		tw.tween_callback(func(): _free_dialog_ref(d))

func _free_dialog_ref(dialog_ref: Control):
	"""Callback to free dialog reference - avoids lambda capture."""
	if is_instance_valid(dialog_ref):
		dialog_ref.queue_free()
	if current_dialog == dialog_ref:
		current_dialog = null

func _spawn_number_later(text: String, delay: float, font_size: int, color: Color, linger: float, is_go: bool = false) -> void:
	var timer := get_tree().create_timer(delay)
	# Don't use .bind() with timeout signal - capture parameters in lambda instead
	var t = text
	var fs = font_size
	var c = color
	var l = linger
	var ig = is_go
	timer.timeout.connect(func(): _spawn_number_now(t, fs, c, l, ig))

func _spawn_number_now(text: String, font_size: int, color: Color, linger: float, is_go: bool = false) -> void:
	var label := Label.new()
	label.text = text
	# Force GO! to start at 100% alpha
	if is_go:
		label.modulate = Color(color.r, color.g, color.b, 1.0)
	else:
		label.modulate = color
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Center the countdown numbers - use large enough size for any text
	var viewport_size = get_viewport().get_visible_rect().size
	var label_width = font_size * 2  # Wide enough for any countdown text
	var label_height = font_size * 1.5  # Tall enough for the font
	label.size = Vector2(label_width, label_height)
	var center_pos = Vector2(viewport_size.x * 0.5 - label_width * 0.5, viewport_size.y * 0.5 - label_height * 0.5)
	label.position = center_pos

	var layer := CanvasLayer.new()
	layer.layer = 100
	if get_tree().current_scene:
		get_tree().current_scene.add_child(layer)
	else:
		get_tree().root.add_child(layer)
	layer.add_child(label)

	var tw := create_tween()
	tw.set_parallel(true)
	var fade_duration = 0.4 + linger
	tw.tween_property(label, "position:y", label.position.y - 80.0, fade_duration)
	tw.tween_property(label, "modulate:a", 0.0, fade_duration)

	# Add shake animation for GO!
	if is_go:
		var shake_tw := create_tween()
		shake_tw.set_loops(int(fade_duration / 0.1))  # Shake every 0.1 seconds
		shake_tw.tween_property(label, "rotation", deg_to_rad(3), 0.05)
		shake_tw.tween_property(label, "rotation", deg_to_rad(-3), 0.05)

	# Capture layer to avoid lambda issues
	var l = layer
	tw.tween_callback(l.queue_free).set_delay(fade_duration)
