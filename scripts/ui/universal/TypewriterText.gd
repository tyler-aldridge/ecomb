extends Control
class_name TypewriterText

## ============================================================================
## TYPEWRITER TEXT COMPONENT
## ============================================================================
## Reusable component for narrative text display with typewriter effect.
##
## Features:
## - Character-by-character typing animation
## - Auto-advance after delay when typing completes
## - Click to fast-forward typing
## - Click again to skip to next message instantly
## - Centered text in 1000px container with auto-wrapping
## ============================================================================

signal typing_complete
signal advance_requested

# Text configuration
@export var text_content: String = ""
@export var typing_speed: float = 0.03  # Seconds per character
@export var auto_advance_delay: float = 3.0  # Seconds after typing completes
@export var max_width: int = 1000

# UI elements
var label: Label
var container: CenterContainer

# State
var current_char_index: int = 0
var is_typing: bool = false
var typing_complete_flag: bool = false
var auto_advance_timer: float = 0.0
var full_text: String = ""
var char_timer: float = 0.0

func _ready():
	# Create container for centering
	container = CenterContainer.new()
	container.size = get_viewport().get_visible_rect().size
	container.position = Vector2.ZERO
	add_child(container)

	# Create label inside container
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(max_width, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Style the label (white pixel font)
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)

	container.add_child(label)

	# Set initial text
	if text_content != "":
		set_text(text_content)

func set_text(new_text: String):
	"""Set new text and start typing animation."""
	full_text = new_text
	current_char_index = 0
	is_typing = true
	typing_complete_flag = false
	auto_advance_timer = 0.0
	label.text = ""

func _process(delta):
	if is_typing:
		_type_next_character(delta)
	elif typing_complete_flag:
		# Auto-advance timer after typing completes
		auto_advance_timer += delta
		if auto_advance_timer >= auto_advance_delay:
			emit_signal("advance_requested")

func _type_next_character(delta):
	"""Type one character at a time."""
	if current_char_index >= full_text.length():
		is_typing = false
		typing_complete_flag = true
		emit_signal("typing_complete")
		return

	# Simple timing (not perfect but sufficient)
	char_timer += delta

	if char_timer >= typing_speed:
		char_timer = 0.0
		label.text += full_text[current_char_index]
		current_char_index += 1

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		_handle_click()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_handle_click()

func _handle_click():
	"""Handle player input to fast-forward or advance."""
	if is_typing:
		# Fast-forward: complete typing instantly
		label.text = full_text
		current_char_index = full_text.length()
		is_typing = false
		typing_complete_flag = true
		emit_signal("typing_complete")
	elif typing_complete_flag:
		# Advance: skip to next message
		emit_signal("advance_requested")

func reset():
	"""Reset the component for reuse."""
	label.text = ""
	current_char_index = 0
	is_typing = false
	typing_complete_flag = false
	auto_advance_timer = 0.0
	full_text = ""
