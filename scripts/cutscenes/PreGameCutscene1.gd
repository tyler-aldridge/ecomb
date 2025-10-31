extends "res://scripts/cutscenes/BasicCutscene.gd"

## ============================================================================
## PRE-GAME CUTSCENE 1
## ============================================================================
## Introduction to Muscle Beach world after character creation.
## 4 messages with typewriter effect, auto-advances to PreGameTutorial.
##
## This scene extends BasicCutscene.gd and sets the narrative messages.
## ============================================================================

func _ready():
	# Set messages for PreGameCutscene1
	messages = [
		"Welcome to Muscle Beach, bro.",
		"The year is 1987. The sun is blazing, the babes are watching, and every flex could be your moment of glory.",
		"You've just stepped off the bus with nothing but a gym bag and the unshakeable feeling that you belong here.",
		"On this beach, respect is earned one perfectly timed flex at a time.",
		"Time to learn the fundamentals..."
	]

	# Set next scene path
	next_scene_path = "res://scenes/tutorials/PreGameTutorial.tscn"

	# Call parent _ready
	super._ready()
