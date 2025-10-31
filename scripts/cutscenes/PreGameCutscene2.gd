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
		"You enter the legendary Muscle Beach Gym. Bronze gods flex in the California sun while admirers gather to witness greatness.",
		"Through the haze of tanning oil and testosterone, a massive figure approaches from behind the gym equipment.",
		"\"Ayo look, fresh meat!\"\n\nA voice cuts through the sound of clinking iron and impressed gasps.",
		"The gym's head trainer steps forward, muscles glistening with earned respect. Time for your first flex off!",
		"\"On this beach, we settle everything through the ancient art of synchronized flexing. Miss the beat, lose your rep.\"",
		"The crowd gathers. This is serious business. Prepare yourself!"
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
