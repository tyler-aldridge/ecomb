extends "res://scripts/cutscenes/BasicCutscene.gd"

## ============================================================================
## PRE-GAME CUTSCENE 2
## ============================================================================
## Introduction to Coach Flex Galaxy before the first rhythm battle.
## 4 messages with typewriter effect, final message reveals Coach sprite.
##
## This scene extends BasicCutscene.gd and adds Coach sprite reveal.
## ============================================================================

var coach_sprite: AnimatedSprite2D

func _ready():
	# Set messages for PreGameCutscene2
	messages = [
		"You approach the legendary Muscle Beach Gym. The neon sign pulses with pure summer energy and absolute confidence in the power of gains.",
		"Through the golden haze of protein powder and coconut oil, a figure emerges from the shadows... Actually, he emerges from the squat rack. Because he was squatting. Obviously.",
		"\"YO! Fresh meat!\" The voice booms like thunder wrapped in compression shorts and unstoppable motivation.",
		"Coach Flex Galaxy steps into the light, biceps gleaming with the wisdom of a thousand reps. Your first test begins..."
	]

	# Set next scene path
	next_scene_path = "res://scenes/battles/PreGameBattle.tscn"

	# Call parent _ready
	super._ready()

	# Create coach sprite (hidden initially)
	# TODO: Load actual Coach Flex Galaxy sprite
	# coach_sprite = AnimatedSprite2D.new()
	# coach_sprite.position = Vector2(960, 540)  # Center of screen
	# coach_sprite.visible = false
	# coach_sprite.z_index = 50
	# add_child(coach_sprite)

func _on_advance_requested():
	# Show coach sprite on the last message
	if current_message_index == messages.size() - 1 and coach_sprite:
		coach_sprite.visible = true
		if coach_sprite.sprite_frames and coach_sprite.sprite_frames.has_animation("idle"):
			coach_sprite.play("idle")

	# Call parent advance logic
	super._on_advance_requested()
