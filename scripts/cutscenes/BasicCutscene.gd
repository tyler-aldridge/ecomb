extends Control

## ============================================================================
## CUTSCENE BASE CONTROLLER
## ============================================================================
## Base class for cutscene sequences with typewriter text and fade transitions.
## Used by PreGameCutscene1, PreGameCutscene2, and future cutscene scenes.
##
## Features:
## - Multiple messages in sequence
## - 3 second fade in at start, instant message transitions with 0.5s pause
## - Gradient background (panel-gradient-3.png)
## - Auto-advances to next scene when complete
## ============================================================================

# Configuration
@export var messages: Array[String] = []
@export var next_scene_path: String = ""
@export var fade_duration: float = 3.0

# UI elements
var typewriter: TypewriterText
var fade_overlay: ColorRect
var background: TextureRect

# State
var current_message_index: int = 0
var is_transitioning: bool = false

func _ready():
	# Create gradient background
	background = TextureRect.new()
	background.texture = preload("res://assets/interface/ui/panel-gradient-3.png")
	background.size = get_viewport().get_visible_rect().size
	background.position = Vector2.ZERO
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(background)

	# Create TypewriterText component
	typewriter = TypewriterText.new()
	typewriter.size = get_viewport().get_visible_rect().size
	add_child(typewriter)

	# Connect signals
	typewriter.advance_requested.connect(_on_advance_requested)

	# Create fade overlay for transitions
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.size = get_viewport().get_visible_rect().size
	fade_overlay.position = Vector2.ZERO
	fade_overlay.z_index = 100
	add_child(fade_overlay)

	# Start with fade in
	fade_from_black()

func fade_from_black():
	"""Fade in from black overlay."""
	fade_overlay.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_start_first_message)

func _start_first_message():
	"""Start displaying the first message."""
	if messages.size() > 0:
		typewriter.set_text(messages[0])

func _input(event):
	"""Handle ESC key to skip cutscene."""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not is_transitioning:
			# Stop typewriter immediately
			if typewriter:
				typewriter.is_typing = false
			_transition_to_next_scene()

func _on_advance_requested():
	"""Handle request to advance to next message or scene."""
	if is_transitioning:
		return

	current_message_index += 1

	if current_message_index < messages.size():
		# Fade out current message, show next
		_transition_to_next_message()
	else:
		# All messages complete, transition to next scene
		_transition_to_next_scene()

func _transition_to_next_message():
	"""Clear current message and show next one after a slight pause."""
	is_transitioning = true

	# Clear current message immediately
	typewriter.set_text("")

	# Wait for a slight pause (0.5 seconds) then show next message
	await get_tree().create_timer(0.5).timeout
	_show_next_message()

func _show_next_message():
	"""Show the next message."""
	typewriter.set_text(messages[current_message_index])
	is_transitioning = false

func _transition_to_next_scene():
	"""Fade to black and load next scene using Router for persistent overlay."""
	is_transitioning = true

	# Use Router's persistent fade overlay to prevent flash during scene transition
	if next_scene_path != "":
		Router.goto_scene_with_fade(next_scene_path, fade_duration)
	else:
		push_error("BasicCutscene: next_scene_path not set!")

func _load_next_scene():
	"""Deprecated - now using Router.goto_scene_with_fade()."""
	pass
